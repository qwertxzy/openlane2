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
  lib,
  stdenv,
  gcc14,
  fetchFromGitHub,
  openroad-abc,
  libsForQt5,
  opensta,
  boost183,
  eigen,
  cudd,
  tcl,
  python3,
  readline,
  tclreadline,
  spdlog-internal-fmt,
  libffi,
  llvmPackages,
  lemon-graph,
  scipopt-scip,
  or-tools,
  glpk,
  zlib,
  clp,
  cbc,
  re2,
  swig4,
  pkg-config,
  gnumake,
  flex,
  bison,
  buildEnv,
  makeBinaryWrapper,
  rev ? "23f3ed6757bd4ea7bff13c76efa1ccb776df9597",
  sha256 ? "sha256-sJASj01uAY/sK3c/sZFzDvazKsAGiQhPMJU49ll7v2s=",
  # environments,
  openroad,
  buildPythonEnvForInterpreter,
}: let
  self = stdenv.mkDerivation (finalAttrs: {
    name = "openroad";
    inherit rev;

    # Force use of GCC
    # strictDeps = true;
    NIX_CFLAGS_COMPILE = "-B${gcc14}/bin";

    src = fetchFromGitHub {
      owner = "qwertxzy";
      repo = "OpenROAD";
      inherit rev;
      inherit sha256;
    };
    
    patches = [
      ./patches/openroad/6743.patch
    ];

    cmakeFlagsAll = [
      "-DTCL_LIBRARY=${tcl}/lib/libtcl${stdenv.hostPlatform.extensions.sharedLibrary}"
      "-DTCL_HEADER=${tcl}/include/tcl.h"
      "-DUSE_SYSTEM_BOOST:BOOL=ON"
      "-DCMAKE_CXX_FLAGS=-I${openroad-abc}/include"
      "-DENABLE_TESTS:BOOL=OFF"
      "-DVERBOSE=1"
    ];

    cmakeFlags =
      finalAttrs.cmakeFlagsAll
      ++ [
        "-DUSE_SYSTEM_ABC:BOOL=ON"
        "-DUSE_SYSTEM_OPENSTA:BOOL=ON"
        "-DCMAKE_CXX_FLAGS=-I${eigen}/include/eigen3"
        "-DOPENSTA_HOME=${opensta}"
        "-DABC_LIBRARY=${openroad-abc}/lib/libabc.a"
      ];

    preConfigure = ''
      sed -i "s/GITDIR-NOTFOUND/${rev}/" ./cmake/GetGitRevisionDescription.cmake
      patchShebangs ./etc/find_messages.py

      sed -i 's@#include "base/abc/abc.h"@#include <base/abc/abc.h>@' src/rmp/src/Restructure.cpp
      sed -i 's@#include "base/main/abcapis.h"@#include <base/main/abcapis.h>@' src/rmp/src/Restructure.cpp
      sed -i 's@# tclReadline@target_link_libraries(openroad readline)@' src/CMakeLists.txt
      sed -i 's@%include "../../src/Exception.i"@%include "../../Exception.i"@' src/dbSta/src/dbSta.i
      sed -i 's@''${TCL_LIBRARY}@''${TCL_LIBRARY}\n${cudd}/lib/libcudd.a@' src/CMakeLists.txt
    '';

    buildInputs = [
      openroad-abc
      boost183
      eigen
      cudd
      tcl
      python3
      readline
      tclreadline
      spdlog-internal-fmt
      libffi
      libsForQt5.qtbase
      libsForQt5.qt5.qtcharts
      llvmPackages.openmp
      lemon-graph
      scipopt-scip
      or-tools
      opensta
      glpk
      zlib
      clp
      cbc
      re2
    ];

    nativeBuildInputs = [
      gcc14
      swig4
      pkg-config
      python3.pkgs.cmake # TODO: Replace with top-level cmake, I'm just doing this to avoid a rebuild
      gnumake
      flex
      bison
      libsForQt5.wrapQtAppsHook
    ];

    shellHook = ''
      export DEVSHELL_CMAKE_FLAGS="${builtins.concatStringsSep " " finalAttrs.cmakeFlagsAll}"
    '';

    passthru = {
      inherit python3;
      withPythonPackages = buildPythonEnvForInterpreter {
        target = openroad;
        inherit lib;
        inherit buildEnv;
        inherit makeBinaryWrapper;
      };
    };

    meta = with lib; {
      description = "OpenROAD's unified application implementing an RTL-to-GDS flow";
      homepage = "https://theopenroadproject.org";
      # OpenROAD code is BSD-licensed, but OpenSTA is GPLv3 licensed,
      # so the combined work is GPLv3
      license = licenses.gpl3Plus;
      platforms = platforms.linux ++ platforms.darwin;
    };
  });
in
  self
