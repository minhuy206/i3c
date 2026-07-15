class i3c_private_rw_stress_stimulus extends uvm_object;
  typedef enum bit [2:0] {
    StressDataRandom,
    StressDataZero,
    StressDataOnes,
    StressDataAlternatingAa,
    StressDataAlternating55,
    StressDataWalkingOne
  } stress_data_pattern_e;

  rand bit                   rnw;
  rand bit             [3:0] tid;
  rand bit                   dev_idx;
  rand bit                   broadcast_header_enable;
  rand int unsigned          data_length;
  rand stress_data_pattern_e data_pattern;
  rand bit             [7:0] data[$];

  constraint data_length_c {
    if (rnw) {
      data_length dist {
        [1:4]  :/ 30,
        [5:8]  :/ 30,
        [9:15] :/ 20,
        16      := 20
      };
    } else {
      data_length dist {
        0       := 10,
        [1:4]  :/ 25,
        [5:8]  :/ 25,
        [9:15] :/ 20,
        16      := 20
      };
    }
  }

  constraint data_pattern_c {
    data_pattern dist {
      StressDataRandom        := 60,
      StressDataZero          := 8,
      StressDataOnes          := 8,
      StressDataAlternatingAa := 8,
      StressDataAlternating55 := 8,
      StressDataWalkingOne    := 8
    };
  }

  constraint payload_c {
    data.size() == data_length;
    foreach (data[i]) {
      if (data_pattern == StressDataZero) {
        data[i] == 8'h00;
      } else if (data_pattern == StressDataOnes) {
        data[i] == 8'hff;
      } else if (data_pattern == StressDataAlternatingAa) {
        data[i] == ((i % 2) == 0 ? 8'haa : 8'h55);
      } else if (data_pattern == StressDataAlternating55) {
        data[i] == ((i % 2) == 0 ? 8'h55 : 8'haa);
      } else if (data_pattern == StressDataWalkingOne) {
        data[i] == (8'h01 << (i % 8));
      }
    }
  }

  `uvm_object_utils_begin(i3c_private_rw_stress_stimulus)
    `uvm_field_int(rnw, UVM_DEFAULT)
    `uvm_field_int(tid, UVM_DEFAULT)
    `uvm_field_int(dev_idx, UVM_DEFAULT)
    `uvm_field_int(broadcast_header_enable, UVM_DEFAULT)
    `uvm_field_int(data_length, UVM_DEFAULT)
    `uvm_field_enum(stress_data_pattern_e, data_pattern, UVM_DEFAULT)
    `uvm_field_queue_int(data, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "i3c_private_rw_stress_stimulus");
    super.new(name);
  endfunction
endclass
