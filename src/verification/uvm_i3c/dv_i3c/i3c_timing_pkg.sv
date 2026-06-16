package i3c_timing_pkg;
  typedef struct {
    int tHoldStop   = 1_300;
    int tHoldStart  = 600;
    int tSetupStart = 600;
    int tSetupBit   = 100;
    int tHoldBit    = 0;
    int tClockPulse = 900;
    int tClockLow   = 1_600;
    int tSetupStop  = 1_300;
  } i2c_timing_t;

  parameter i2c_timing_t I2C_400 = '{
      tHoldStop   : 1_300,
      tHoldStart  : 600,
      tSetupStart : 600,
      tSetupBit   : 100,
      tHoldBit    : 0,
      tClockPulse : 900,
      tClockLow   : 1_600,
      tSetupStop  : 1_300
  };

  typedef struct {
    int tHoldStop   = 39;
    int tHoldStart  = 39;
    int tSetupStart = 20;
    int tHoldRStart = 20;
    int tSetupBit   = 3;
    int tHoldBit    = 0;
    int tClockPulse = 32;
    int tClockLowOD = 200;
    int tClockLowPP = 48;
    int tSetupStop  = 20;
    int tSCO        = 12;
  } i3c_timing_t;

  parameter i3c_timing_t I3C_SDR = '{
      tHoldStop   : 39,
      tHoldStart  : 39,
      tSetupStart : 20,
      tHoldRStart : 20,
      tSetupBit   : 3,
      tHoldBit    : 0,
      tClockPulse : 32,
      tClockLowOD : 200,
      tClockLowPP : 48,
      tSetupStop  : 20,
      tSCO        : 12
  };

  typedef struct {
    i2c_timing_t i2c_tc;
    i3c_timing_t i3c_tc;
  } bus_timing_t;
endpackage : i3c_timing_pkg
