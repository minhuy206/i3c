module edge_detector #(
  parameter int CounterWidth = 20,
  parameter bit DETECT_NEGEDGE = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        trigger,      // Raw edge detection pulse
  input  logic        line,         // Current line value (registered)
  input  logic [CounterWidth-1:0] delay_count,  // Rise/fall time in clock cycles
  output logic        detect        // Confirmed edge pulse
);

  logic [CounterWidth-1:0] count;
  logic check_in_progress;
  logic detect_line;
  logic detect_internal;

  assign detect_line = line ^ DETECT_NEGEDGE;
  assign detect = (delay_count == 0) ? trigger : detect_internal;

  always_ff @(posedge clk_i or negedge rst_ni ) begin
    if (!rst_ni) begin
      count <= '0;
      check_in_progress <= 1'b0;
      detect_internal <= 1'b0;
    end else if (trigger) begin
      check_in_progress <= 1'b1;
      count <= '0;
    end else if (check_in_progress && detect_line) begin
      count <= count + 1'b1;
      if (count >= delay_count) begin
        check_in_progress <= 1'b0;
        detect_internal <= 1'b1;
      end
    end else begin
      detect_internal <= 1'b0;
    end
  end
 
endmodule