from cProfile import label
from re import S
import sys
import numpy as np
from PNM import *
import math
import json
from ctypes import *
from dataclasses import dataclass
from plyfile import PlyData, PlyElement
import struct
def convert_ply_to_verilog():
    input_ply_filename = sys.argv[1]
    i_array_ptr = 0
    v_array_ptr = 0
    f_array_ptr = 0    
    res_x = 100
    res_y = 100
    with open(input_ply_filename, 'rb') as f:
        plydata = PlyData.read(f)

        print(plydata['vertex'][0])
        index_addr_counter = 0
        index_verilog_code = ""
        for index in plydata['face']:
            
            for i in index[0]:
                attr_write_str = f"tri_mem_wr_data = 'h{hex(i)[(-1*len(hex(i))+2):]};\n"  
                
                addr_write_str = f"tri_mem_wr_addr = 'd{i_array_ptr + index_addr_counter};\n#(PERIOD);\n"
                index_addr_counter += 1
                index_verilog_code = f"{index_verilog_code}{attr_write_str}{addr_write_str}"

        v_array_ptr = i_array_ptr + index_addr_counter + 1
        vertex_addr_counter = 0
        vertex_verilog_code = ""
        for vertex in plydata['vertex']:
            v = vertex.tolist()
         
            print(v)
            for attr_num in range(0,len(v)):
                if attr_num == 0:
                    attr = (v[attr_num]/2 + 1) *(res_x/2)+0.001
                elif attr_num == 1:
                    attr = (v[attr_num]/2 + 1) *(res_x/2)+0.001
                else:
                    attr = v[attr_num]

                attr_write_str = f"tri_mem_wr_data = 'h{float_to_hex(attr)[(-1*len(float_to_hex(attr))+2):]};\n"  
                addr_write_str = f"tri_mem_wr_addr = 'd{v_array_ptr + vertex_addr_counter};\n#(PERIOD);\n"
                vertex_addr_counter += 1
                vertex_verilog_code = f"{vertex_verilog_code}{attr_write_str}{addr_write_str}"
            
            attr_write_str = "tri_mem_wr_data = 'h123;\n"  
            addr_write_str = f"tri_mem_wr_addr = 'd{v_array_ptr + vertex_addr_counter};\n#(PERIOD);\n"
            vertex_addr_counter += 1
            vertex_verilog_code = f"{vertex_verilog_code}{attr_write_str}{addr_write_str}"
        
        f_array_ptr = v_array_ptr + vertex_addr_counter + 1

        ptr_verilog_code = f"i_array_ptr = 'd{i_array_ptr};\nv_array_ptr = 'd{v_array_ptr};\nf_array_ptr = 'd{f_array_ptr};\n#PERIOD;\ntri_mem_wr_en = 1'b1;\n"

        verilog_code = ""
        num_triangles_verilog_code = f"ctrl_reg1[15:0] = 'd{int(index_addr_counter/3)};\n"
        resolution_verilog_code = f"res_reg[31:16] = {res_x};\nres_reg[15:0] = {res_y};\n"
        verilog_code = f"{num_triangles_verilog_code}{resolution_verilog_code}{ptr_verilog_code}{index_verilog_code}{vertex_verilog_code}endmodule"
        return verilog_code
            # i_array_ptr = I_AR

def float_to_hex(f):
    return hex(struct.unpack('<I', struct.pack('<f', f))[0])

def main():
    
    out = convert_ply_to_verilog()
    print(out)
if '__main__' == __name__:
    main()
