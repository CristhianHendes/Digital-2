// FSM del divisor: misma estructura de 3 fases que control_mult.v
// (arranque/ejecucion/fin), pero aqui la fase de ejecucion dura
// exactamente 32 ciclos (uno por cada bit del dividendo), contados
// con "count", en vez de terminar por deteccion de "z" como en mult.
module control_div (clk, rst, init, done, load, shift);

  input clk;
  input rst;
  input init;

  output reg done;
  output reg load;
  output reg shift;

  parameter START = 2'b00;
  parameter RUN   = 2'b01;
  parameter END   = 2'b10;

  reg [1:0] state;
  reg [5:0] count; // 0..31: un ciclo por cada bit del dividendo (32 bits)

  initial begin
    state = START;
    count = 6'd0;
    done  = 0;
    load  = 0;
    shift = 0;
  end

  always @(posedge clk) begin
    if (rst) begin
      state <= START;
      count <= 6'd0;
    end else begin
      case (state)
        START: begin
          count <= 6'd0;
          if (init)
            state <= RUN;
        end

        RUN: begin
          count <= count + 6'd1;
          if (count == 6'd31)
            state <= END;
        end

        END: begin
          if (init)
            state <= START;
        end

        default: state <= START;
      endcase
    end
  end

  always @(*) begin
    case (state)
      START: begin done = 0; load = 1; shift = 0; end
      RUN:   begin done = 0; load = 0; shift = 1; end
      END:   begin done = 1; load = 0; shift = 0; end
      default: begin done = 0; load = 1; shift = 0; end
    endcase
  end

`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case (state)
    START: state_name = "START";
    RUN:   state_name = "RUN";
    END:   state_name = "END";
  endcase
end
`endif

endmodule
