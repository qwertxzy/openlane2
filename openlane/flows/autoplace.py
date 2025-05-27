"""
Defines several flows which compare to the classic flow,
but automatically place macros. The three variations are
- TritonMP: Uses TritonMacroPlace for macro placement.
- HierRTLMP: Uses the hierarchical macro placer.
- Legalize: Uses the global placer for macro placement.
"""

from .flow import Flow
from .classic import Classic
from .sequential import SequentialFlow
from ..steps import (
    Yosys,
    OpenROAD,
    Magic,
    KLayout,
    Odb,
    Netgen,
    Checker,
    Verilator,
    Misc,
)

# NOTE: This could probably be done cleaner with gating variables, but it's easier like this

@Flow.factory.register()
class TritonMP(SequentialFlow):
  """
  The classic openlane 1.0 flow with TritonMacroPlace for macro placement.
  """
  Steps = [
      Verilator.Lint,
      Checker.LintTimingConstructs,
      Checker.LintErrors,
      Checker.LintWarnings,
      Yosys.JsonHeader,
      Yosys.Synthesis,
      Checker.YosysUnmappedCells,
      Checker.YosysSynthChecks,
      Checker.NetlistAssignStatements,
      OpenROAD.CheckSDCFiles,
      OpenROAD.CheckMacroInstances,
      OpenROAD.STAPrePNR,
      OpenROAD.Floorplan,
      Odb.CheckMacroAntennaProperties,
      Odb.SetPowerConnections,
      OpenROAD.GlobalPlacementSkipIO,
      OpenROAD.IOPlacement,
      #  OpenROAD.UnplaceAll,
      Odb.CustomIOPlacement,
      Odb.ApplyDEFTemplate,
      # Call TritonMacroPlace
      OpenROAD.TritonMacroPlacer,
      # Unplace all stdcells again
      OpenROAD.UnplaceStdCells,
      OpenROAD.CutRows,
      OpenROAD.TapEndcapInsertion,
      Odb.AddPDNObstructions,
      OpenROAD.GeneratePDN,
      Odb.RemovePDNObstructions,
      Odb.AddRoutingObstructions,
      OpenROAD.GlobalPlacementSkipIO,
      OpenROAD.IOPlacement,
      Odb.CustomIOPlacement,
      Odb.ApplyDEFTemplate,
      OpenROAD.GlobalPlacement,
      Odb.WriteVerilogHeader,
      Checker.PowerGridViolations,
      OpenROAD.STAMidPNR,
      OpenROAD.RepairDesignPostGPL,
      Odb.ManualGlobalPlacement,
      OpenROAD.DetailedPlacement,
      OpenROAD.CTS,
      OpenROAD.STAMidPNR,
      OpenROAD.ResizerTimingPostCTS,
      OpenROAD.STAMidPNR,
      OpenROAD.GlobalRouting,
      OpenROAD.CheckAntennas,
      OpenROAD.RepairDesignPostGRT,
      Odb.DiodesOnPorts,
      Odb.HeuristicDiodeInsertion,
      OpenROAD.RepairAntennas,
      OpenROAD.ResizerTimingPostGRT,
      OpenROAD.STAMidPNR,
      OpenROAD.DetailedRouting,
      Odb.RemoveRoutingObstructions,
      OpenROAD.CheckAntennas,
      Checker.TrDRC,
      Odb.ReportDisconnectedPins,
      Checker.DisconnectedPins,
      Odb.ReportWireLength,
      Checker.WireLength,
      OpenROAD.FillInsertion,
      Odb.CellFrequencyTables,
      OpenROAD.RCX,
      OpenROAD.STAPostPNR,
      OpenROAD.IRDropReport,
      Magic.StreamOut,
      KLayout.StreamOut,
      Magic.WriteLEF,
      Odb.CheckDesignAntennaProperties,
      KLayout.XOR,
      Checker.XOR,
      Magic.DRC,
      KLayout.DRC,
      Checker.MagicDRC,
      Checker.KLayoutDRC,
      Magic.SpiceExtraction,
      Checker.IllegalOverlap,
      Netgen.LVS,
      Checker.LVS,
      Yosys.EQY,
      Checker.SetupViolations,
      Checker.HoldViolations,
      Checker.MaxSlewViolations,
      Checker.MaxCapViolations,
      Misc.ReportManufacturability,
  ]

  # Steal these from the classic flow
  gating_config_vars = Classic.gating_config_vars
  config_vars = Classic.config_vars