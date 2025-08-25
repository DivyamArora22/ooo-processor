package rv32i_types;

    //yes
    localparam ROB_DEPTH = 8; //power of 2
    localparam IQUEUE_DEPTH = 64; //power of 2
    localparam SQUEUE_DEPTH = 8; //power of 2

    localparam NUM_ALU = 3;
    localparam NUM_L = 3;
    localparam NUM_MUL = 3;

    //params
    localparam NUM_PHYSICAL_REGISTERS = 64; //no
    localparam PREG_IDX_WIDTH = $clog2(NUM_PHYSICAL_REGISTERS);
    localparam ROB_PACKET_WIDTH = (PREG_IDX_WIDTH + 5);
    localparam ROB_IDX_WIDTH = $clog2(ROB_DEPTH);

   typedef struct packed {
       logic                       cdb_valid;
       logic [ROB_IDX_WIDTH-1:0]   rob_index;
       logic [4:0]                 areg_index;
       logic [PREG_IDX_WIDTH-1:0]  preg_index;
       logic [31:0]                result;
       logic                       branch_flag;
       logic                       take_branch;
       logic [31:0]                jalr_return_pc;
       logic                       jalr_flag;

       logic                        branch_taken;
       logic [31:0]                 branch_taken_pc;
       logic                        branch_commit;
   } cdb_t;

     typedef struct packed {
        logic [4:0]                 areg_index; 
        logic [PREG_IDX_WIDTH -1:0] preg_index;
        logic [ROB_IDX_WIDTH-1:0]   rob_index;
        logic [31:0]                target_pc;
        logic                       branch_taken;
        logic                       take_branch;

   } rob_packet_t;

   typedef struct packed {
       logic                           valid;
       logic [3:0]                     op;
       logic [1:0]                     station_index;
       logic                           ps1_valid;
       logic [PREG_IDX_WIDTH-1:0]      ps1;
       logic                           ps2_valid;
       logic [PREG_IDX_WIDTH-1:0]      ps2;
       logic                           imm_flag;
       logic [31:0]                    imms;
       logic                           pc_flag;
       logic [31:0]                    return_pc;
       logic                            prediction;

       logic [31:0]                     ls_ps1_v;
       logic [31:0]                     ls_ps2_v;

       logic [PREG_IDX_WIDTH-1:0]      pd;
       logic [4:0]                     rd;
       logic [ROB_IDX_WIDTH-1:0]       rob_index;
       logic [6:0]                     opcode;
       logic [2:0]                     cmpop;
   } reservation_station_entry_t;

   typedef struct packed {
    reservation_station_entry_t         rs;
    logic [31:0]                        ls_ps1_v;
    logic [31:0]                        ls_ps2_v;
    logic [31:0]                        tgt_address;
    logic [31:0]                        wdata;
    logic [31:0]                        age;
   } s_queue_entry_t;

   typedef struct packed {
    reservation_station_entry_t         rs;
    logic [31:0]                        ls_ps1_v;
    logic [31:0]                        ls_ps2_v;
    logic [2:0]                         store_ptr;
    logic [31:0]                        age;
   } l_entry_t;

   typedef struct packed {
       logic   [6:0]       funct7;
       logic   [2:0]       funct3;
       logic   [6:0]       opcode;
       logic   [3:0]       aluop;
       logic   [3:0]       mulop;
       logic   [4:0]       rd_addr;
       logic   [4:0]       rs1_addr;
       logic   [4:0]       rs2_addr;
       logic   [31:0]      imm;
       logic   [2:0]       cmpop;

   } decode_stage_reg_t;

   typedef struct packed {
       logic           valid;
       logic   [63:0]  order;
       logic   [31:0]  inst;
       logic   [4:0]   rs1_addr;
       logic   [4:0]   rs2_addr;
       logic   [31:0]  rs1_rdata;
       logic   [31:0]  rs2_rdata;
       logic   [4:0]   rd_addr;
       logic   [31:0]  rd_wdata;
       logic   [31:0]  pc_rdata;
       logic   [31:0]  pc_wdata;

       logic [PREG_IDX_WIDTH-1:0] ps1_addr;
       logic [PREG_IDX_WIDTH-1:0] ps2_addr;
       
       logic   [31:0]  mem_addr;
       logic   [3:0]   mem_rmask;
       logic   [3:0]   mem_wmask;
       logic   [31:0]  mem_rdata;
       logic   [31:0]  mem_wdata;
       
   } rvfi_signals_t;

   typedef struct packed {
        logic                       valid;
        logic [ROB_IDX_WIDTH-1:0]   rob_idx;
        logic [31:0]                addr;
        logic [3:0]                 rmask;
        logic [3:0]                 wmask;
        logic [31:0]                rdata;
        logic [31:0]                wdata; 
        logic [31:0]                rs1_rdata;
        logic [31:0]                rs2_rdata;
   } rvfi_mem_packet_t;

   typedef struct packed {
        logic [3:0] rmask;
        logic [3:0] wmask;
        logic [31:0] wdata;
        logic [31:0] addr;

        logic [22:0] tag;
        logic [3:0] cache_set;
        logic [4:0] offset;

   } cache_pipeline_reg_t;

   typedef logic [PREG_IDX_WIDTH-1:0] free_list_entry_t;
   typedef logic [2:0] l_res_station_slicer_t;

   typedef enum logic [2:0] {
       WAIT        = 3'b000,
       BURSTING1    = 3'b001,
       BURSTING2   = 3'b010,
       BURSTING3    = 3'b011,
       BURSTING4    = 3'b100,
       DONE        = 3'b101
   } cacheline_adapter_state_t;

   typedef enum logic [6:0] {
       op_b_lui       = 7'b0110111, // load upper immediate (U type)
       op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
       op_b_jal       = 7'b1101111, // jump and link (J type)
       op_b_jalr      = 7'b1100111, // jump and link register (I type)
       op_b_br        = 7'b1100011, // branch (B type)
       op_b_load      = 7'b0000011, // load (I type)
       op_b_store     = 7'b0100011, // store (S type)
       op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
       op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
   } rv32i_opcode;

   typedef enum logic [3:0] {
       mul_f3_mul      = 4'b0000,
       mul_f3_mulh     = 4'b0001,
       mul_f3_mulhsu   = 4'b0010,
       mul_f3_mulhu    = 4'b0011,
       mul_f3_div      = 4'b0100,
       mul_f3_divu     = 4'b0101,
       mul_f3_rem      = 4'b0110,
       mul_f3_remu     = 4'b0111
   } mul_f3_t;

   typedef enum logic [2:0] {
       arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
       arith_f3_sll   = 3'b001,
       arith_f3_slt   = 3'b010,
       arith_f3_sltu  = 3'b011,
       arith_f3_xor   = 3'b100,
       arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
       arith_f3_or    = 3'b110,
       arith_f3_and   = 3'b111
   } arith_f3_t;

   typedef enum logic [2:0] {
       load_f3_lb     = 3'b000,
       load_f3_lh     = 3'b001,
       load_f3_lw     = 3'b010,
       load_f3_lbu    = 3'b100,
       load_f3_lhu    = 3'b101
   } load_f3_t;

   typedef enum logic [2:0] {
       store_f3_sb    = 3'b000,
       store_f3_sh    = 3'b001,
       store_f3_sw    = 3'b010
   } store_f3_t;

   typedef enum logic [2:0] {
       branch_f3_beq  = 3'b000,
       branch_f3_bne  = 3'b001,
       branch_f3_blt  = 3'b100,
       branch_f3_bge  = 3'b101,
       branch_f3_bltu = 3'b110,
       branch_f3_bgeu = 3'b111
   } branch_f3_t;

   typedef enum logic [6:0] {
       base           = 7'b0000000,
       variant        = 7'b0100000,
       multiply       = 7'b0000001
   } funct7_t;

   typedef enum logic [3:0] {
       alu_op_add     = 4'b0000,
       alu_op_sll     = 4'b0001,
       alu_op_sra     = 4'b0010,
       alu_op_sub     = 4'b0011,
       alu_op_xor     = 4'b0100,
       alu_op_srl     = 4'b0101,
       alu_op_or      = 4'b0110,
       alu_op_and     = 4'b0111,
       alu_op_slt     = 4'b1100,
       alu_op_sltu    = 4'b1110,
       alu_op_jalr    = 4'b1111,
       alu_op_jal    = 4'b1010
   } alu_ops;

   typedef union packed {
       logic [31:0] word;

       struct packed {
           logic [11:0] i_imm;
           logic [4:0]  rs1;
           logic [2:0]  funct3;
           logic [4:0]  rd;
           rv32i_opcode opcode;
       } i_type;

       struct packed {
           logic [6:0]  funct7;
           logic [4:0]  rs2;
           logic [4:0]  rs1;
           logic [2:0]  funct3;
           logic [4:0]  rd;
           rv32i_opcode opcode;
       } r_type;

       struct packed {
           logic [11:5] imm_s_top;
           logic [4:0]  rs2;
           logic [4:0]  rs1;
           logic [2:0]  funct3;
           logic [4:0]  imm_s_bot;
           rv32i_opcode opcode;
       } s_type;


       struct packed {
        // Fill this out to get branches running!
           logic [6:0] imm_b_top;
           logic [4:0] rs2;
           logic [4:0] rs1;
           logic [2:0] funct3;
           logic [4:0] imm_b_bot;
           rv32i_opcode opcode;
       } b_type;

       struct packed {
           logic [31:12] imm;
           logic [4:0]   rd;
           rv32i_opcode  opcode;
       } j_type;

       struct packed {
           logic [31:12] imm;
           logic [4:0]   rd;
           rv32i_opcode  opcode;
       } u_type;

   } instr_t;


endpackage : rv32i_types

