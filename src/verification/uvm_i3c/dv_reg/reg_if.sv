interface reg_if (
    input clk_i,
    input rst_ni,
    input resp_valid_i
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

  modport drv(clocking cb, input clk_i, input rst_ni);

  task automatic read(input bit [11:0] addr, output bit [31:0] data);
    @(cb);
    cb.addr <= addr;
    cb.wen  <= 1'b0;
    cb.ren  <= 1'b1;
    @(cb);  // T+1: RTL latches rdata_comb into rdata_o
    cb.ren <= 1'b0;  // 1-cycle ren pulse — preserves FIFO pop semantics
    @(cb);  // T+2: rdata_o is now the registered value
    while (!cb.ready) @(cb);  // stall handling
    data = cb.rdata;
  endtask

  task automatic write(input bit [11:0] addr, input bit [31:0] data);
    @(cb);
    cb.addr  <= addr;
    cb.wdata <= data;
    cb.wen   <= 1'b1;
    cb.ren   <= 1'b0;
    @(cb);
    while (!cb.ready) @(cb);  // stall handling
    cb.wen <= 1'b0;
  endtask
endinterface
