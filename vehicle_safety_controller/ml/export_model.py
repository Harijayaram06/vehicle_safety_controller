#!/usr/bin/env python3
"""Export an ALREADY trained/quantized JSON model to synthesizable case ROM.
The required explicit model_status prevents verification coefficients being mistaken for training.
Run: python3 ml/export_model.py path/to/model.json --output rtl/mlp_parameter_rom.v
"""
import argparse, json
from pathlib import Path
from reference_inference import validate
ap=argparse.ArgumentParser(); ap.add_argument('model'); ap.add_argument('--output',required=True)
a=ap.parse_args(); model=json.loads(Path(a.model).read_text()); validate(model)
if model.get('model_status') != 'trained_quantized':
    raise SystemExit('Refusing model without model_status=trained_quantized; fixtures are not training.')
if not model.get('training_manifest'):
    raise SystemExit('Provide training_manifest provenance, data split and quantization evaluation.')
lines=['`timescale 1ns/1ps','// Generated model ROM. Preserve source model and training provenance.',
'module mlp_parameter_rom(input wire [6:0] weight_address, input wire [3:0] bias_address,',
'output reg signed [7:0] weight_data, output reg signed [23:0] bias_data,',
'output wire [24:0] margin_min, output wire model_valid);',
f"assign margin_min=25'd{model['margin_min']};", "assign model_valid=1'b1;",
'always @* begin', "weight_data=8'sd0;", 'case(weight_address)']
for i,v in enumerate(model['weights']): lines.append(f"7'd{i}: weight_data=8'sh{v&255:02x};")
lines+=['default: begin end','endcase','end','always @* begin',"bias_data=24'sd0;",'case(bias_address)']
for i,v in enumerate(model['biases']): lines.append(f"4'd{i}: bias_data=24'sh{v&0xffffff:06x};")
lines+=['default: begin end','endcase','end','endmodule']
Path(a.output).write_text('\n'.join(lines)+'\n')
print('Exported',a.output)
