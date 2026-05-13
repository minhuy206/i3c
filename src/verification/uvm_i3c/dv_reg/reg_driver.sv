class reg_driver extends uvm_driver #(reg_seq_item);
  `uvm_component_utils(reg_driver)

  reg_agent_cfg  cfg;
  virtual reg_if vif;

  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual reg_if)::get(this, "", "vif", this.vif))
      `uvm_fatal(`gfn, "reg_driver: failed to get vif from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      this.reset_signals();
      this.get_and_drive();
    join_none
  endtask

  task get_and_drive();
    forever begin
      this.seq_item_port.get_next_item(this.req);

      if (this.req.is_write) begin
        this.vif.write(this.req.addr, this.req.wdata);
      end else begin
        this.vif.read(this.req.addr, this.req.rdata);
      end

      `uvm_info(`gfn, this.req.convert2string(), UVM_HIGH)
      this.seq_item_port.item_done(this.req);
    end
  endtask

  task reset_signals();
    forever begin
      @(negedge this.vif.rst_ni);
      this.vif.cb.wen   <= 1'b0;
      this.vif.cb.ren   <= 1'b0;
      this.vif.cb.addr  <= '0;
      this.vif.cb.wdata <= '0;
      @(posedge this.vif.rst_ni);
    end
  endtask
endclass
