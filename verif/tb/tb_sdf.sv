// Task 22: annotates the post-PnR netlist with an SDF file. Separate top module, so tb_top.sv
// (the checks) is shared unchanged with the RTL and gate-level simulations.
//   iverilog ... -s tb_top -s sdf_load -DSDF_FILE='"pnr/final/sdf/<corner>/<file>.sdf"'
module sdf_load;
  initial begin
    $sdf_annotate(`SDF_FILE, tb_top.dut, , "verif/out/pnr/sdf_annotate.log", "MAXIMUM");
  end
endmodule
