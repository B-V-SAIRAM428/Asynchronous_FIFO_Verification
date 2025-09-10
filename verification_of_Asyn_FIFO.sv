`include "uvm_macros.svh"
import uvm_pkg::*;

////////////// Write and Read interface /////////

interface wr_intf #(parameter wr_width=16)(input logic wr_clk, input logic wr_rst);
    logic wr_en;
    logic [wr_width-1:0] wr_data;
    logic full;
endinterface

interface rd_intf #(parameter rd_width =8) (input logic rd_clk, input logic rd_rst);
    logic rd_en;
    logic [rd_width-1:0] rd_data;
    logic rd_valid;
    logic empty;
endinterface

///////////// Write and Read transaction //////// 

class wr_transaction#(parameter wr_width =16) extends uvm_sequence_item;
    rand logic wr_en;
    rand logic [wr_width-1:0] wr_data;
    logic full;
    
    function new(string name="wr_transaction");
        super.new(name);
    endfunction 

    `uvm_object_param_utils_begin(wr_transaction#(wr_width))
        `uvm_field_int(wr_en,UVM_ALL_ON)
        `uvm_field_int(wr_data,UVM_ALL_ON)
        `uvm_field_int(full,UVM_ALL_ON)
    `uvm_object_utils_end
endclass

class rd_transaction#(parameter rd_width =8) extends uvm_sequence_item;
    rand logic rd_en;
    logic [rd_width-1:0] rd_data;
    logic rd_valid;
    logic empty;

    function new(string name="rd_transaction");
        super.new(name);
    endfunction 

    `uvm_object_param_utils_begin(rd_transaction#(rd_width))
        `uvm_field_int(rd_en,UVM_ALL_ON)
        `uvm_field_int(rd_data,UVM_ALL_ON)
        `uvm_field_int(empty,UVM_ALL_ON)
        `uvm_field_int(rd_valid,UVM_ALL_ON)
    `uvm_object_utils_end
endclass

/////////  Write and Read Sequence /////////////

class wr_sequence#(parameter wr_width=16,depth = 512) extends uvm_sequence#(wr_transaction#(wr_width));
    `uvm_object_param_utils(wr_sequence#(wr_width,depth))
    
    function new(string name="wr_sequence");
        super.new(name);
    endfunction

    task body();
        
        repeat(depth+3) begin
            wr_transaction#(wr_width) wr_trans;
            wr_trans = wr_transaction#(wr_width)::type_id::create("wr_trans");
            start_item(wr_trans);
            assert(wr_trans.randomize() with {wr_trans.wr_en ==1;});
            finish_item(wr_trans);
        end

        repeat(3) begin
            wr_transaction#(wr_width) wr_trans;
            wr_trans = wr_transaction#(wr_width)::type_id::create("wr_trans");
            start_item(wr_trans);
            assert(wr_trans.randomize() with {wr_trans.wr_en ==0; wr_trans.wr_data ==0;});
            finish_item(wr_trans);
        end
    endtask
endclass

class rd_sequence#(parameter rd_width=8, depth = 512) extends uvm_sequence#(rd_transaction#(rd_width));
    `uvm_object_param_utils(rd_sequence#(rd_width,depth))
    
    function new(string name="rd_sequence");
        super.new(name);
    endfunction

    task body();
      
        repeat(2) begin
            rd_transaction#(rd_width) rd_trans;
            rd_trans = rd_transaction#(rd_width)::type_id::create("rd_trans");
            start_item(rd_trans);
            rd_trans.rd_en = 0;
            finish_item(rd_trans);
        end
      
        repeat(depth+3) begin
            rd_transaction#(rd_width) rd_trans;
            rd_trans = rd_transaction#(rd_width)::type_id::create("rd_trans");
            start_item(rd_trans);
            rd_trans.rd_en = 1;
            finish_item(rd_trans);
        end
    endtask
endclass

////////////// Write and Read sequencer ////////////
class wr_sequencer#(parameter wr_width=16) extends uvm_sequencer#(wr_transaction#(wr_width));
    `uvm_component_param_utils(wr_sequencer#(wr_width))
    
    function new(string name="wr_sequencer", uvm_component parent);
        super.new(name,parent);
    endfunction
endclass

class rd_sequencer#(parameter rd_width=8) extends uvm_sequencer#(rd_transaction#(rd_width));
    `uvm_component_param_utils(rd_sequencer#(rd_width))
    
    function new(string name="rd_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

//////////// Write and Read Driver /////////////

class wr_driver#(parameter wr_width=16) extends uvm_driver#(wr_transaction#(wr_width));
    `uvm_component_param_utils(wr_driver#(wr_width))
    virtual wr_intf#(wr_width) wr_vif;

    function new(string name="wr_driver", uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual wr_intf#(wr_width))::get(this, "", "wr_vif", wr_vif))
            `uvm_fatal("DRIVER","no virtual interface");
    endfunction 

    task run_phase(uvm_phase phase);
        forever begin
            wr_transaction#(wr_width) wr_trans;
            seq_item_port.get_next_item(wr_trans);
            @(posedge wr_vif.wr_clk);
                wr_vif.wr_en = wr_trans.wr_en;
                wr_vif.wr_data = wr_trans.wr_data;
            seq_item_port.item_done();
        end
    endtask
endclass

class rd_driver#(parameter rd_width=8) extends uvm_driver#(rd_transaction#(rd_width));
    `uvm_component_param_utils(rd_driver#(rd_width))
    virtual rd_intf#(rd_width) rd_vif;

    function new(string name="rd_driver", uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual rd_intf#(rd_width))::get(this, "", "rd_vif", rd_vif))
            `uvm_fatal("read DRIVER","no virtual interface");
    endfunction 

    task run_phase(uvm_phase phase);
        forever begin
            rd_transaction#(rd_width) rd_trans;
            seq_item_port.get_next_item(rd_trans);
            @(posedge rd_vif.rd_clk);
                rd_vif.rd_en = rd_trans.rd_en;
            seq_item_port.item_done();
        end
    endtask
endclass

///////////// Write and Read Monitor /////////////

class wr_monitor#(parameter wr_width=16) extends uvm_monitor;
    `uvm_component_param_utils(wr_monitor#(wr_width))
    virtual wr_intf#(wr_width) wr_vif;
    uvm_analysis_port#(wr_transaction#(wr_width)) wr_ap;

    function new(string name="wr_monitor",uvm_component parent);
        super.new(name,parent);
        wr_ap = new("wr_ap",this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual wr_intf#(wr_width))::get(this, "", "wr_vif", wr_vif))
            `uvm_fatal("wr_monitor","no virtual interface");
    endfunction 

    task run_phase(uvm_phase phase);
        forever begin
            wr_transaction#(wr_width) wr_trans;
            wr_trans = wr_transaction#(wr_width)::type_id::create("wr_trans");
            @(posedge wr_vif.wr_clk);
            wr_trans.wr_en = wr_vif.wr_en;
            wr_trans.wr_data = wr_vif.wr_data;
            wr_trans.full = wr_vif.full;
            wr_ap.write(wr_trans);
        end
    endtask
endclass

class rd_monitor#(parameter rd_width=8) extends uvm_monitor;
    `uvm_component_param_utils(rd_monitor#(rd_width))
    virtual rd_intf#(rd_width) rd_vif;
    uvm_analysis_port#(rd_transaction#(rd_width)) rd_ap;

    function new(string name="rd_monitor", uvm_component parent);
        super.new(name,parent);
        rd_ap = new("rd_ap",this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual rd_intf#(rd_width))::get(this, "", "rd_vif", rd_vif))
            `uvm_fatal("rd_monitor","no virtual interface");
    endfunction 

    task run_phase(uvm_phase phase);
        forever begin
            rd_transaction#(rd_width) rd_trans;
            rd_trans = rd_transaction#(rd_width)::type_id::create("rd_trans");
            @(posedge rd_vif.rd_clk);
            rd_trans.rd_en = rd_vif.rd_en;
            rd_trans.rd_data = rd_vif.rd_data;
            rd_trans.empty = rd_vif.empty;
            rd_trans.rd_valid = rd_vif.rd_valid;
            rd_ap.write(rd_trans);
        end
    endtask
endclass

////////////// Write and Read Agent ////////////

class wr_agent#(parameter wr_width = 16) extends uvm_agent;
    `uvm_component_param_utils(wr_agent#(wr_width))
    
    wr_sequencer #(wr_width) wr_sequ;
    wr_monitor #(wr_width) wr_mon;
    wr_driver #(wr_width) wr_dri;

    function new(string name = "wr_agent", uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        wr_mon = wr_monitor#(wr_width)::type_id::create("wr_mon", this);

        if(get_is_active() == UVM_ACTIVE) begin
            wr_sequ = wr_sequencer #(wr_width)::type_id::create("wr_sequ",this);
            wr_dri = wr_driver #(wr_width)::type_id::create("wr_dri",this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(get_is_active() == UVM_ACTIVE)
            wr_dri.seq_item_port.connect(wr_sequ.seq_item_export);
    endfunction
endclass

class rd_agent#(parameter rd_width = 8) extends uvm_agent;
    `uvm_component_param_utils(rd_agent#(rd_width))
    
    rd_sequencer #(rd_width) rd_sequ;
    rd_monitor #(rd_width) rd_mon;
    rd_driver #(rd_width) rd_dri;

    function new(string name = "rd_agent", uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        rd_mon = rd_monitor#(rd_width)::type_id::create("rd_mon", this);

        if(get_is_active() == UVM_ACTIVE) begin
            rd_sequ = rd_sequencer #(rd_width)::type_id::create("rd_sequ",this);
            rd_dri = rd_driver #(rd_width)::type_id::create("rd_dri",this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(get_is_active() == UVM_ACTIVE)
            rd_dri.seq_item_port.connect(rd_sequ.seq_item_export);
    endfunction
endclass

//////////// Scoreboard //////////

class my_sb#(parameter wr_width = 16, 
             parameter rd_width = 8, 
             parameter depth = 512, 
             parameter width = (wr_width < rd_width) ? wr_width : rd_width) extends uvm_scoreboard;
    `uvm_component_param_utils(my_sb#(wr_width, rd_width, depth))

    `uvm_analysis_imp_decl(_wr)
    `uvm_analysis_imp_decl(_rd)
    uvm_analysis_imp_wr#(wr_transaction#(wr_width), my_sb#(wr_width,rd_width,depth)) wr_imp;
    uvm_analysis_imp_rd#(rd_transaction#(rd_width), my_sb#(wr_width,rd_width,depth)) rd_imp;

    logic [width-1:0] mem[$];
    localparam k1 = wr_width/width;
    localparam k2 = rd_width/width;
    bit control = 1;
    int wr_count = 0;  // Count of width-sized words written
    int rd_count = 0;  // Count of width-sized words read
    function new(string name = "my_sb", uvm_component parent);
        super.new(name, parent);
        wr_imp = new("wr_imp", this);
        rd_imp = new("rd_imp", this);
    endfunction

    function void write_wr(wr_transaction#(wr_width) wr_trans);
        if(wr_trans.wr_en && !wr_trans.full) begin
            logic [width-1:0] wr_value;
            for(int w = 0; w < k1; w++) begin
                wr_value = wr_trans.wr_data[(w+1)*width-1 -: width];
                mem.push_back(wr_value);
            end
            wr_count += k1;
            `uvm_info("SB_WRITE", $sformatf("Write successful - Data: 0x%0h, Queue size: %0d", 
                     wr_trans.wr_data, mem.size()), UVM_MEDIUM)
        end else if(wr_trans.wr_en && wr_trans.full) begin
            `uvm_info("SB_WRITE", "Write blocked - FIFO full (Expected behavior)", UVM_LOW)

        end else if(!wr_trans.wr_en) begin
            `uvm_info("SB_WRITE", "Write not enabled", UVM_HIGH)
	end
 
    endfunction

    function void write_rd(rd_transaction#(rd_width) rd_trans);
    if(rd_trans.rd_en &&  !rd_trans.empty) begin
        if(rd_trans.rd_valid) begin
            logic [rd_width-1:0] expected = 0;
            if(mem.size() >= k2) begin
                // Match the FIFO's read bit ordering exactly
                for(int r = 0; r < k2; r++) begin    
                    expected[(r+1)*width-1 -: width] = mem.pop_front();
                end
                rd_count += k2;
                if(expected == rd_trans.rd_data) begin
                    `uvm_info("SB_READ", $sformatf("PASS - Expected: 0x%0h, Got: 0x%0h, Queue size: %0d", 
                             expected, rd_trans.rd_data, mem.size()), UVM_MEDIUM)
                end else begin
                    `uvm_error("SB_READ", $sformatf("FAIL - Expected: 0x%0h, Got: 0x%0h", 
                              expected, rd_trans.rd_data))
                end
            end else begin
                `uvm_error("SB_READ", $sformatf("Not enough data in memory - Available: %0d, Required: %0d", 
                          mem.size(), k2))
            end
        end else begin
            `uvm_info("SB_READ", "Read attempted but data not valid yet", UVM_HIGH)
        end
    end else if(rd_trans.rd_en && rd_trans.empty) begin
        `uvm_info("SB_READ", "Read blocked - FIFO empty (Expected behavior)", UVM_LOW)
    end else if(!rd_trans.rd_en) begin
        `uvm_info("SB_READ", "Read not enabled", UVM_HIGH)
    end 
endfunction
endclass

//////////// Write Coverage ///////////

class wr_coverage#(parameter wr_width=16) extends uvm_subscriber#(wr_transaction#(wr_width));
    `uvm_component_param_utils(wr_coverage#(wr_width))
    wr_transaction#(wr_width) wr_trans;
    
    covergroup wr_cg;
        option.per_instance = 1;
        cp_wr_en    : coverpoint wr_trans.wr_en;
        cp_wr_data  : coverpoint wr_trans.wr_data {
            option.auto_bin_max = 16;
        }
        cp_full     : coverpoint wr_trans.full;
        
    endgroup

    function new(string name="wr_coverage", uvm_component parent=null);
        super.new(name,parent);
        wr_cg = new();
    endfunction

    function void write(wr_transaction#(wr_width) t);
        wr_trans = t;
        wr_cg.sample();
    endfunction
endclass

class rd_coverage#(parameter rd_width=8) extends uvm_subscriber#(rd_transaction#(rd_width));
    `uvm_component_param_utils(rd_coverage#(rd_width))

    rd_transaction#(rd_width) rd_trans;

    covergroup rd_cg;
        option.per_instance = 1;
        cp_rd_en     : coverpoint rd_trans.rd_en;
        cp_rd_valid  : coverpoint rd_trans.rd_valid;
        cp_empty     : coverpoint rd_trans.empty;
        cp_rd_data   : coverpoint rd_trans.rd_data {
           option.auto_bin_max = 16;

        }

    endgroup

    function new(string name="rd_coverage", uvm_component parent=null);
        super.new(name,parent);
        rd_cg = new();
    endfunction

    function void write(rd_transaction#(rd_width) t);
        rd_trans = t;
        rd_cg.sample();
    endfunction
endclass

//////////// Environment ///////////

class my_env #(parameter wr_width =16, 
               parameter rd_width=8, 
               parameter depth=512) extends uvm_env;
    
    `uvm_component_param_utils(my_env#(wr_width,rd_width,depth))
    
    wr_agent#(wr_width) wr_age;
    rd_agent#(rd_width) rd_age;
    my_sb#(wr_width,rd_width,depth) sb;
    wr_coverage#(wr_width) wr_cov;
    rd_coverage#(rd_width) rd_cov;
    
    function new(string name="my_env", uvm_component parent);
        super.new(name,parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_age = wr_agent#(wr_width)::type_id::create("wr_age",this);
        rd_age = rd_agent#(rd_width)::type_id::create("rd_age",this);
        sb = my_sb#(wr_width,rd_width,depth)::type_id::create("sb",this);
        wr_cov = wr_coverage#(wr_width)::type_id::create("wr_cov",this);
        rd_cov = rd_coverage#(rd_width)::type_id::create("rd_cov",this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        wr_age.wr_mon.wr_ap.connect(sb.wr_imp);
        rd_age.rd_mon.rd_ap.connect(sb.rd_imp);
        wr_age.wr_mon.wr_ap.connect(wr_cov.analysis_export);
        rd_age.rd_mon.rd_ap.connect(rd_cov.analysis_export);
    endfunction
endclass

/////// Test ///////

class my_test extends uvm_test;
    `uvm_component_utils(my_test)

    localparam wr_width = 8;
    localparam rd_width = 8;
    localparam depth    = 512;

    my_env #(wr_width,rd_width,depth) env;
    wr_sequence #(wr_width,depth) wr_seq;
    rd_sequence #(rd_width,depth) rd_seq;



    function new(string name="my_test", uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = my_env #(wr_width,rd_width,depth)::type_id::create("env",this);
        wr_seq = wr_sequence #(wr_width,depth)::type_id::create("wr_seq");
        rd_seq = rd_sequence #(rd_width,depth)::type_id::create("rd_seq");
        uvm_config_db#(uvm_active_passive_enum)::set(null,"env.wr_age","is_active",UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(null,"env.rd_age","is_active",UVM_ACTIVE);
    endfunction    

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        fork
           
                wr_seq.start(env.wr_age.wr_sequ); 

            begin : READ_THREAD
                #100;
                rd_seq.start(env.rd_age.rd_sequ);
            end
        join

        phase.drop_objection(this);
    endtask
endclass


//////////////// top ////////

module verification_of_Asyn_FIFO();
    reg wr_clk;
    reg wr_rst;
    reg rd_clk;
    reg rd_rst;

    wr_intf#(.wr_width(8)) wr_vif(wr_clk,wr_rst);
    rd_intf#(.rd_width(8)) rd_vif(rd_clk,rd_rst);
    
    FIFO #(.wr_width(8),
           .rd_width(8),
           .depth(512)) dut (
        .wr_clk(wr_clk),
        .wr_rst(wr_rst),
        .rd_clk(rd_clk),
        .rd_rst(rd_rst),
        .wr_en(wr_vif.wr_en),
        .rd_en(rd_vif.rd_en),
        .wr_data(wr_vif.wr_data),
        .rd_data(rd_vif.rd_data),
        .full(wr_vif.full),
        .empty(rd_vif.empty),
        .rd_valid(rd_vif.rd_valid)
    );

    always #5 wr_clk = ~wr_clk;
    always #7 rd_clk = ~rd_clk;

    initial begin    
        wr_clk = 0; wr_rst = 1; rd_clk = 0; rd_rst = 1;
	#20;
         wr_rst = 0;
	 rd_rst = 0;
    
        uvm_config_db#(virtual wr_intf#(8))::set(null, "*", "wr_vif", wr_vif);
        uvm_config_db#(virtual rd_intf#(8))::set(null, "*", "rd_vif", rd_vif);
        run_test("my_test");
    end

endmodule
