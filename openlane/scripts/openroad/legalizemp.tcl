# Copyright 2020-2022 Efabless Corporation
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
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb

# Macro legalizer only supports uniform halos so print a warning if vertical and horizontal halos are not the same.
if { $::env(FP_MACRO_HORIZONTAL_HALO) != $::env(FP_MACRO_VERTICAL_HALO) } {
    puts "\[WARNING\] Macro legalizer only supports uniform halos. Using horizontal halo for both dimensions."
}

# Call with just horizontal
fix_macros -halo_width $::env(FP_MACRO_HORIZONTAL_HALO)

write_views

report_design_area_metrics

