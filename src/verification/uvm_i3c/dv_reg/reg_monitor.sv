class reg_monitor extends uvm_monitor;
  `uvm_component_utils(reg_monitor)

  reg_agent_cfg cfg;
  virtual reg_if vif;

  uvm_analysis_port #(reg_seq_item) analysis_port;

  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
    if (!uvm_config_db#(virtual reg_if)::get(this, "", "vif", vif))
      `uvm_fatal(`gfn, "reg_monitor: failed to get vif from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (!vif.rst_ni) continue;

      if (vif.wen) begin
        reg_seq_item item = reg_seq_item::type_id::create("item");
        item.is_write = 1'b1;
        item.addr = vif.addr;
        item.wdata = vif.wdata;
        `uvm_info(`gfn, item.convert2string(), UVM_HIGH)
        analysis_port.write(item);
      end

      if (vif.ren) begin
        reg_seq_item item = reg_seq_item::type_id::create("item");
        item.is_write = 1'b0;
        item.addr = vif.addr;
        @(posedge vif.clk_i);
        item.rdata = vif.rdata;
        `uvm_info(`gfn, item.convert2string(), UVM_HIGH)
        analysis_port.write(item);
      end
    end
  endtask
endclass
