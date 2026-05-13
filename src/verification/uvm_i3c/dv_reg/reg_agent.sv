class reg_agent extends uvm_agent;
    `uvm_component_utils(reg_agent)

    reg_agent_cfg cfg;
    reg_driver driver;
    reg_sequencer sequencer;
    reg_monitor monitor;
    virtual reg_if vif;

    function new(string name = "", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(reg_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal(`gfn, "Failed to get reg_agent_cfg")

        monitor = reg_monitor::type_id::create("monitor", this);

        if(cfg.is_active) begin
            sequencer = reg_sequencer::type_id::create("sequencer", this);
            if(cfg.has_driver)
                driver = reg_driver::type_id::create("driver", this);
        end

        if(!uvm_config_db#(virtual reg_if)::get(this, "", "vif", vif))
            `uvm_fatal(`gfn, "Failed to get reg_if")
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        uvm_config_db#(reg_agent_cfg)::set(this, "*", "cfg", cfg);

        uvm_config_db#(virtual reg_if)::set(this, "*", "vif", vif);

        if(cfg.is_active && cfg.has_driver)
            driver.seq_item_port.connect(sequencer.req_item_export);
    endfunction
endclass
