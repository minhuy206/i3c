interface reg_if (
    input clk_i,
    input rst_ni
);
  logic [11:0] addr;
  logic [31:0] wdata;
  logic wen;
  logic ren;
  logic [31:0] rdata;
  logic ready;

  clocking cb @(posedge clk_i);
    input rdata, ready;
    output addr, wdata, wen, ren;
  endclocking

  modport dv(clocking cb, input clk_i, input rst_ni);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      addr  <= '0;
      wdata <= '0;
      wen   <= 1'b0;
      ren   <= 1'b0;
    end
  end

  task automatic read(input bit [11:0] a, output bit [31:0] d);
    @(cb);
    cb.addr <= a;
    cb.wen  <= 1'b0;
    cb.ren  <= 1'b1;
    @(cb);
    while (!cb.ready) @(cb);  // stall handling
    d = cb.rdata;
    cb.ren <= 1'b0;
  endtask

  task automatic write(input bit [11:0] a, input bit [31:0] d);
    @(cb);
    cb.addr  <= a;
    cb.wdata <= d;
    cb.wen   <= 1'b1;
    cb.ren   <= 1'b0;
    @(cb);
    while (!cb.ready) @(cb);  // stall handling
    cb.wen <= 1'b0;
  endtask
endinterface
