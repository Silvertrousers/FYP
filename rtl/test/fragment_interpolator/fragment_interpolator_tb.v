
module fragment_interpolator_tb();



// fragment_interpolator_Test#(
//     {32'h3e800000,32'h3e800000},
//     'b0,
//     'b0,
//     'b0,
//     4'd15
// ) Test_withPersp ();



// fragment_interpolator_Test#(
//     {32'h3e800000,32'h3e800000},
//     'b1,
//     'b0,
//     'b0,
//     4'd15
// ) Test_noPersp ();



fragment_interpolator_Test#(
    {32'h3e800000,32'h3e800000},
    'b0,
    'b1,
    'b0,
    4'd15
) Test_flat_provokeA ();


endmodule

