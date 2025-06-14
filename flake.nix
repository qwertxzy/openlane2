# Copyright 2023 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
{
  description = "open-source infrastructure for implementing chip design flows";
  
  nixConfig = {
    extra-substituters = [
      "https://openlane.cachix.org"
    ];
    extra-trusted-public-keys = [
      "openlane.cachix.org-1:qqdwh+QMNGmZAuyeQJTH9ErW57OWSvdtuwfBKdS254E="
    ];
  };

  inputs = {
    nix-eda.url = github:efabless/nix-eda/2.1.2;
    libparse.url = github:efabless/libparse-python;
    ioplace-parser.url = github:efabless/ioplace_parser;
    volare.url = github:efabless/volare;
    devshell.url = github:numtide/devshell;
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
    nixpkgs-main.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  inputs.libparse.inputs.nixpkgs.follows = "nix-eda/nixpkgs";
  inputs.ioplace-parser.inputs.nix-eda.follows = "nix-eda";
  inputs.volare.inputs.nixpkgs.follows = "nix-eda/nixpkgs";
  inputs.devshell.inputs.nixpkgs.follows = "nix-eda/nixpkgs";

  outputs = {
    self,
    nix-eda,
    libparse,
    ioplace-parser,
    volare,
    devshell,
    nixpkgs-main,
    ...
  }: let
    nixpkgs = nix-eda.inputs.nixpkgs;
    lib = nixpkgs.lib;
  in {
    # Common
    overlays = {
      default = lib.composeManyExtensions [
        (import ./nix/overlay.nix)
        (nix-eda.flakesToOverlay [libparse ioplace-parser volare])
        (pkgs': pkgs: {
          yosys-sby = (pkgs.yosys-sby.override { sha256 = "sha256-Il2pXw2doaoZrVme2p0dSUUa8dCQtJJrmYitn1MkTD4="; });
          klayout = (pkgs.klayout.overrideAttrs(old: {
            configurePhase = builtins.replaceStrings ["-without-qtbinding"] ["-with-qtbinding"] old.configurePhase;
          }));
          yosys = pkgs.yosys.overrideAttrs(old: {
            patches = old.patches ++ [
              ./nix/patches/yosys/async_rules.patch
            ];
          });
          gcc14 = pkgs.gcc14;
        })
        (
          pkgs': pkgs: let
            nixpkgs-main-pkgs = import nixpkgs-main { 
              inherit (pkgs) system; 
              overlays = [
                (final: prev: {
                  # or-tools needs SCIP support for the rtl macro placer, which isn't present by default
                  or-tools = prev.or-tools.overrideAttrs (finalAttrs: previousAttrs: {
                    cmakeFlags = previousAttrs.cmakeFlags or [] ++ [
                      "-DUSE_SCIP=ON"
                      "-DSCIP_ROOT=${final.scipopt-scip}"
                      "-DCMAKE_CXX_STANDARD=17"
                    ];
                    
                    # Having format strings of raw c strings throws an error now, so replace f(str) with f("%s", str)
                    preConfigure = ''
                      sed -i 's/SCIPerrorMessage(gresult\.status()\.ToString()\.c_str())/SCIPerrorMessage("%s", gresult.status().ToString().c_str())/g' ortools/gscip/gscip_constraint_handler.cc
                    '';
                  });
                })
              ];
            };
            callPackage = lib.callPackageWith pkgs';
          in {
            colab-env = callPackage ./nix/colab-env.nix {};
            opensta = callPackage ./nix/opensta.nix {};
            openroad-abc = callPackage ./nix/openroad-abc.nix {};
            openroad = callPackage ./nix/openroad.nix {
              scipopt-scip = nixpkgs-main-pkgs.scipopt-scip;
              or-tools = nixpkgs-main-pkgs.or-tools;
            };

            or-tools = nixpkgs-main-pkgs.or-tools;
          }
        )
        (
          nix-eda.composePythonOverlay (pkgs': pkgs: pypkgs': pypkgs: let
            callPythonPackage = lib.callPackageWith (pkgs' // pkgs'.python3.pkgs);
          in {
            mdformat = pypkgs.mdformat.overridePythonAttrs (old: {
              patches = [
                ./nix/patches/mdformat/donns_tweaks.patch
              ];
              doCheck = false;
            });
            sphinx-tippy = callPythonPackage ./nix/sphinx-tippy.nix {};
            sphinx-subfigure = callPythonPackage ./nix/sphinx-subfigure.nix {};
            yamlcore = callPythonPackage ./nix/yamlcore.nix {};

            # ---
            openlane = callPythonPackage ./default.nix {};
          })
        )
        (pkgs': pkgs: let
          callPackage = lib.callPackageWith pkgs';
        in
          {}
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            openlane-docker = callPackage ./nix/docker.nix {
              createDockerImage = nix-eda.createDockerImage;
              openlane = pkgs'.python3.pkgs.openlane;
            };
          })
      ];
    };

    # Helper functions
    createOpenLaneShell = import ./nix/create-shell.nix;

    # Packages
    legacyPackages = nix-eda.forAllSystems (
      system:
        import nix-eda.inputs.nixpkgs {
          inherit system;
          overlays = [devshell.overlays.default nix-eda.overlays.default self.overlays.default];
        }
    );

    packages = nix-eda.forAllSystems (
      system: let
        pkgs = (self.legacyPackages."${system}");
        in {
          inherit (pkgs) colab-env opensta openroad-abc openroad;
          inherit (pkgs.python3.pkgs) openlane;
          default = pkgs.python3.pkgs.openlane;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          inherit (pkgs) openlane-docker;
        }
    );

    # devshells

    devShells = nix-eda.forAllSystems (
      system: let
        pkgs = self.legacyPackages."${system}";
        callPackage = lib.callPackageWith pkgs;
      in {
        # These devShells are rather unorthodox for Nix devShells in that they
        # include the package itself. For a proper devShell, try .#dev.
        default =
          callPackage (self.createOpenLaneShell {
            }) {};
        notebook = callPackage (self.createOpenLaneShell {
          extra-packages = with pkgs; [
            jupyter
          ];
        }) {};
        # Normal devShells
        dev = callPackage (self.createOpenLaneShell {
          extra-packages = with pkgs; [
            jdupes
            alejandra
          ];
          extra-python-packages = with pkgs.python3.pkgs; [
            pyfakefs
            pytest
            pytest-xdist
            pytest-cov
            pillow
            mdformat
            black
            ipython
            tokenize-rt
            flake8
            mypy
            types-deprecated
            types-pyyaml
            types-psutil
            lxml-stubs
          ];
          include-openlane = false;
        }) {};
        docs = callPackage (self.createOpenLaneShell {
          extra-packages = with pkgs; [
            jdupes
            alejandra
            imagemagick
            nodejs.pkgs.nodemon
          ];
          extra-python-packages = with pkgs.python3.pkgs; [
            pyfakefs
            pytest
            pytest-xdist
            pillow
            mdformat
            furo
            docutils
            sphinx
            sphinx-autobuild
            sphinx-autodoc-typehints
            sphinx-design
            myst-parser
            docstring-parser
            sphinx-copybutton
            sphinxcontrib-spelling
            sphinxcontrib-bibtex
            sphinx-tippy
            sphinx-subfigure
          ];
          include-openlane = false;
        }) {};
      }
    );
  };
}
