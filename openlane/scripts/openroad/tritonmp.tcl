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

macro_placement\
    -channel "$::env(FP_MACRO_HORIZONTAL_HALO) $::env(FP_MACRO_VERTICAL_HALO)" \
    -halo "$::env(FP_MACRO_HORIZONTAL_CHANNEL) $::env(FP_MACRO_VERTICAL_CHANNEL)"

write_views

report_design_area_metrics

