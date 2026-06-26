module bus_monitor
  import i3c_pkg::bus_state_t, i3c_pkg::signal_state_t;
#(
    parameter int CounterWidth = 20
) (
    input logic clk_i,
    input logic rst_ni,

    input logic enable_i,
    input logic scl_i,
    input logic sda_i,

    input logic [CounterWidth-1:0] t_r_i,
    input logic [CounterWidth-1:0] t_f_i,

    output bus_state_t state_o
);
  logic enable;

  logic scl;
  logic scl_negedge_i;
  logic scl_posedge_i;
  logic scl_negedge;
  logic scl_posedge;
  logic scl_edge;
  logic scl_stable_high;
  logic scl_stable_low;

  logic sda;
  logic sda_negedge;
  logic sda_posedge;
  logic sda_negedge_i;
  logic sda_posedge_i;
  logic sda_edge;
  logic sda_stable_high;

  logic start_det_trigger, start_det_pending;
  logic start_det;  // indicates start or repeated start is detected on the bus
  logic stop_det_trigger, stop_det_pending;
  logic stop_det;  // indicates stop is detected on the bus
  logic start_candidate;
  logic stop_candidate;
  logic start_candidate_q;
  logic stop_candidate_q;
  logic scl_high_at_sda_edge;

  logic rstart_detection_en;

  assign enable = enable_i;

  // SDA and SCL at the previous clock edge
  logic scl_i_q, sda_i_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : bus_prev
    if (!rst_ni) begin
      scl_i_q <= 1'b1;
      sda_i_q <= 1'b1;
    end else begin
      scl_i_q <= scl_i;
      sda_i_q <= sda_i;
    end
  end

  assign scl_negedge_i = scl_i_q && !scl_i;
  assign scl_posedge_i = !scl_i_q && scl_i;
  assign sda_negedge_i = sda_i_q && !sda_i;
  assign sda_posedge_i = !sda_i_q && sda_i;

  assign scl_edge = scl_negedge | scl_posedge;
  assign sda_edge = sda_negedge | sda_posedge;

  edge_detector #(
      .DETECT_NEGEDGE(1'b1)
  ) edge_detector_scl_negedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(scl_negedge_i),
      .line(scl_i_q),
      .delay_count(t_f_i),
      .detect(scl_negedge)
  );

  edge_detector edge_detector_scl_posedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(scl_posedge_i),
      .line(scl_i_q),
      .delay_count(t_r_i),
      .detect(scl_posedge)
  );

  edge_detector #(
      .DETECT_NEGEDGE(1'b1)
  ) edge_detector_sda_negedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(sda_negedge_i),
      .line(sda_i_q),
      .delay_count(t_f_i),
      .detect(sda_negedge)
  );

  edge_detector edge_detector_sda_posedge (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .trigger(sda_posedge_i),
      .line(sda_i_q),
      .delay_count(t_r_i),
      .detect(sda_posedge)
  );

  stable_high_detector stable_detector_sda_high (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(sda_i_q),
      .delay_count_i(t_r_i),
      .stable_o(sda_stable_high)
  );

  stable_high_detector stable_detector_scl_high (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(scl_i_q),
      .delay_count_i(t_r_i),
      .stable_o(scl_stable_high)
  );

  stable_high_detector stable_detector_scl_low (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .line_i(!scl_i_q),
      .delay_count_i(t_f_i),
      .stable_o(scl_stable_low)
  );

  // Synchronize input SDA/SCL to edge detectors
  logic sda_r;
  logic scl_r;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sda_r <= '1;
    end else begin
      if (sda_posedge) begin
        sda_r <= '1;
      end else if (sda_negedge) begin
        sda_r <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      scl_r <= '1;
    end else begin
      if (scl_posedge) begin
        scl_r <= '1;
      end else if (scl_negedge) begin
        scl_r <= '0;
      end
    end
  end

  assign sda = sda_r | sda_posedge;
  assign scl = scl_r | scl_posedge;

  assign scl_high_at_sda_edge = scl_stable_high && scl_i_q && scl_i;

  assign start_candidate = sda_negedge_i ? (scl_high_at_sda_edge && sda_r) :
                                           start_candidate_q;
  assign stop_candidate = sda_posedge_i ? (scl_high_at_sda_edge && !sda_r) :
                                          stop_candidate_q;

  // Classify START/STOP candidates when the raw SDA transition occurs, then
  // wait for the delayed edge detector to confirm the transition was stable.
  // This prevents a data-bit SDA transition during SCL LOW from being reported
  // later as START/STOP after SCL has risen. The filtered SDA state qualifier
  // also rejects the return edge of a short SDA glitch.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_candidate_q <= 1'b0;
    end else if (!enable) begin
      start_candidate_q <= 1'b0;
    end else if (sda_negedge_i) begin
      start_candidate_q <= scl_high_at_sda_edge && sda_r;
    end else if (sda_posedge_i || sda_negedge) begin
      start_candidate_q <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      stop_candidate_q <= 1'b0;
    end else if (!enable) begin
      stop_candidate_q <= 1'b0;
    end else if (sda_posedge_i) begin
      stop_candidate_q <= scl_high_at_sda_edge && !sda_r;
    end else if (sda_negedge_i || sda_posedge) begin
      stop_candidate_q <= 1'b0;
    end
  end


  // Start and Stop detection
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_det_pending <= 1'b0;
    end else if (start_det_trigger) begin
      start_det_pending <= 1'b1;
    end else if (!enable || !scl || start_det || stop_det_trigger) begin
      start_det_pending <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      stop_det_pending <= 1'b0;
    end else if (stop_det_trigger) begin
      stop_det_pending <= 1'b1;
    end else if (!enable || !scl || stop_det || start_det_trigger) begin
      stop_det_pending <= 1'b0;
    end
  end

  // START/Repeated START distinction
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      rstart_detection_en <= '0;
    end else begin
      if (stop_det) begin
        rstart_detection_en <= '0;
      end else if (start_det) begin
        rstart_detection_en <= '1;
      end
    end
  end

  // (Repeated) Start condition detection by target
  assign start_det_trigger = enable & start_candidate & sda_negedge;
  assign start_det = enable & start_det_pending;

  // Stop condition detection by target
  assign stop_det_trigger = enable & stop_candidate & sda_posedge;
  assign stop_det = enable & stop_det_pending;

  // Detection output
  assign state_o.sda.value = sda;
  assign state_o.sda.pos_edge = sda_posedge;
  assign state_o.sda.neg_edge = sda_negedge;
  assign state_o.sda.stable_high = sda_stable_high;
  assign state_o.sda.stable_low = '0;  // Unused

  assign state_o.scl.value = scl;
  assign state_o.scl.pos_edge = scl_posedge;
  assign state_o.scl.neg_edge = scl_negedge;
  assign state_o.scl.stable_high = scl_stable_high;
  assign state_o.scl.stable_low = scl_stable_low;

  assign state_o.start_det = start_det & ~rstart_detection_en;
  assign state_o.rstart_det = start_det & rstart_detection_en;
  assign state_o.stop_det = stop_det;
endmodule
