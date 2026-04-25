// ELE432 Assignment 2
// controller.sv

//TOP MODULE
module controller(
    input  logic        clk, reset,
    input  logic [6:0]  op,
    input  logic [2:0]  funct3,
    input  logic        funct7b5,
    input  logic        zero,
    output logic [1:0]  immsrc,
    output logic [1:0]  alusrca, alusrcb,
    output logic [1:0]  resultsrc,
    output logic        adrsrc,
    output logic [2:0]  alucontrol,
    output logic        irwrite, pcwrite,
    output logic        regwrite, memwrite
);

    logic [1:0] aluop;
    logic       branch, pcupdate;

maindec md(
    .clk(clk), .reset(reset),
    .op(op),
    .alusrca(alusrca), .alusrcb(alusrcb),
    .resultsrc(resultsrc), .adrsrc(adrsrc),
    .aluop(aluop),
    .irwrite(irwrite),
    .pcupdate(pcupdate),
    .regwrite(regwrite), .memwrite(memwrite),
    .branch(branch)
);
    
	aludec  	ad(.opb5(op[5]), .funct3(funct3), .funct7b5(funct7b5), .ALUOp(aluop), .ALUControl(alucontrol));                                     
    
	instrdec 	id(.op(op), .ImmSrc(immsrc));

    assign pcwrite = pcupdate | (branch & zero);

endmodule

// MainDec Submodule-------------------------
module maindec(
    input  logic        clk, reset,
    input  logic [6:0]  op,
    output logic [1:0]  alusrca, alusrcb,
    output logic [1:0]  resultsrc,
    output logic        adrsrc,
    output logic [1:0]  aluop,
    output logic        irwrite, pcupdate,
    output logic        regwrite, memwrite,
    output logic        branch
);
logic [3:0] state, nextstate;

always_ff @(posedge clk, posedge reset)
    if (reset) state <= 4'd0;  // reset → S0 Fetch
    else       state <= nextstate;
	always_comb begin
    case(state)
        4'd0: nextstate = 4'd1;  // Fetch → always Decode
        4'd1: case(op)           // Decode → depends on op
			7'b0000011: nextstate = 4'd2 ; // lw
			7'b0100011: nextstate = 4'd2 ; // sw
			7'b0110011: nextstate = 4'd6 ; // R-type
			7'b0010011: nextstate = 4'd8 ; // I-type Alu
			7'b1101111: nextstate = 4'd9 ; // jal
			7'b1100011: nextstate = 4'd10; // beq
			default:	nextstate = 4'd0 ;
        endcase
		4'd2: case(op)
			7'b0000011: nextstate = 4'd3 ;
			7'b0100011: nextstate = 4'd5 ;
			default: 	nextstate = 4'd0 ;
			endcase
		4'd3: nextstate = 4'd4;
		4'd4: nextstate = 4'd0;
		4'd5: nextstate = 4'd0;
		4'd6: nextstate = 4'd7;
		4'd7: nextstate = 4'd0;
		4'd8: nextstate = 4'd7;
		4'd9: nextstate = 4'd7;
		4'd10:nextstate = 4'd0;
		default: nextstate = 4'd0;
    endcase
end
always_comb begin
    // default everything to 0 first
    {alusrca, alusrcb, resultsrc, adrsrc, aluop,
     irwrite, pcupdate, regwrite, memwrite, branch} = '0;
    
        case(state)
            4'd0: begin  // Fetch
                irwrite   = 1'b1;
                pcupdate  = 1'b1;
                alusrca   = 2'b00;
                alusrcb   = 2'b10;
                aluop     = 2'b00;
                resultsrc = 2'b10;
            end
            4'd1: begin  // Decode
                alusrca = 2'b01;
                alusrcb = 2'b01;
                aluop   = 2'b00;
            end
            4'd2: begin  // MemAdr
                alusrca = 2'b10;
                alusrcb = 2'b01;
                aluop   = 2'b00;
            end
            4'd3: begin  // MemRead
                resultsrc = 2'b00;
                adrsrc    = 1'b1;
            end
            4'd4: begin  // MemWB
                resultsrc = 2'b01;
                regwrite  = 1'b1;
            end
            4'd5: begin  // MemWrite
                resultsrc = 2'b00;
                adrsrc    = 1'b1;
                memwrite  = 1'b1;
            end
            4'd6: begin  // ExecuteR
                alusrca = 2'b10;
                alusrcb = 2'b00;
                aluop   = 2'b10;
            end
            4'd7: begin  // ALUWB
                resultsrc = 2'b00;
                regwrite  = 1'b1;
            end
            4'd8: begin  // ExecuteI
                alusrca = 2'b10;
                alusrcb = 2'b01;
                aluop   = 2'b10;
            end
            4'd9: begin  // JAL
                alusrca   = 2'b01;
                alusrcb   = 2'b10;
                aluop     = 2'b00;
                resultsrc = 2'b00;
                pcupdate  = 1'b1;
            end
            4'd10: begin  // BEQ
                alusrca   = 2'b10;
                alusrcb   = 2'b00;
                aluop     = 2'b01;
                resultsrc = 2'b00;
                branch    = 1'b1;
            end
        endcase
    end
endmodule

// AluDec Submodule--------------------------
module aludec(input logic opb5,
	 input logic [2:0] funct3,
	 input logic funct7b5,
	 input logic [1:0] ALUOp,
	 output logic [2:0] ALUControl);
	 logic RtypeSub;
	 assign RtypeSub = funct7b5 & opb5; // TRUE for R-type subtract instruction
	 always_comb
		 case(ALUOp)
		 2'b00: ALUControl = 3'b010; // addition
		 2'b01: ALUControl = 3'b110; // subtraction
			default: case(funct3) // R-type or I-type ALU
			3'b000: if (RtypeSub)
			ALUControl = 3'b110; // sub
			else
			ALUControl = 3'b010; // add, addi
			3'b010: ALUControl = 3'b111; // slt, slti
			3'b110: ALUControl = 3'b001; // or, ori
			3'b111: ALUControl = 3'b000; // and, andi
			default: ALUControl = 3'bxxx; // ???
			endcase
		 endcase
endmodule

// InstrDec Submodule-------------------------
module instrdec (input logic [6:0] op,
	 output logic [1:0] ImmSrc);
	 always_comb
	 case(op)
		 7'b0110011: ImmSrc = 2'bxx; // R-type
		 7'b0010011: ImmSrc = 2'b00; // I-type ALU
		 7'b0000011: ImmSrc = 2'b00; // lw
		 7'b0100011: ImmSrc = 2'b01; // sw
		 7'b1100011: ImmSrc = 2'b10; // beq
		 7'b1101111: ImmSrc = 2'b11; // jal
		 default: ImmSrc = 2'bxx;    // ???
	 endcase
endmodule