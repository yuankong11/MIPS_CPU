module icache(
    input         clk,
    input         resetn,

    input  [11:0] pgOffsetIn,
    input         pgOffsetValid,
    input  [19:0] tagIn,
    input         tagValid,

    output [31:0] dataOut,
    output        dataOutReady,

    output [31:0] addr2Cache2,
    output        addr2Cache2Valid,
    input  [31:0] data2ICacheBlk1,
    input  [31:0] data2ICacheBlk2,
    input  [31:0] data2ICacheBlk3,
    input  [31:0] data2ICacheBlk4,
    input  [31:0] data2ICacheBlk5,
    input  [31:0] data2ICacheBlk6,
    input  [31:0] data2ICacheBlk7,
    input  [31:0] data2ICacheBlk8,
    input         dataRequestedReady,
    input         data2ICacheBlkReady,

    output busy
);

    //I-cache global state machine definition.
    parameter FREE     = 0;
    parameter PGOFF_OK = 1;
    parameter TAG_OK   = 2;
    parameter WR_CTRL  = 3;
    parameter SELECT   = 4;
    parameter REQ_SND  = 5;
    parameter REQ_RTN  = 6;
    parameter BLK_RTN  = 7;
    parameter WR_BLK   = 8;

    //State machine.
    //Global reg:
    reg [4:0] stage;

    //stage TagOK reg:
    reg [ 19:0] tag;
    reg [ 11:0] pgOffset;

    wire [ 6:0] index;
    wire [ 4:0] blkOffset;
    wire [19:0] tagWay1;
    wire [19:0] tagWay2;
    wire [19:0] tagWay3;
    wire [19:0] tagWay4;
    wire [ 1:0] LRUWay1;
    wire [ 1:0] LRUWay2;
    wire [ 1:0] LRUWay3;
    wire [ 1:0] LRUWay4;
    wire        validWay1;
    wire        validWay2;
    wire        validWay3;
    wire        validWay4;
    wire        iCacheHitWay1;
    wire        iCacheHitWay2;
    wire        iCacheHitWay3;
    wire        iCacheHitWay4;
    wire        iCacheHit;

    //stage Write Control & Select reg:
    reg [19:0] nxtTag;
    reg [ 6:0] nxtIndex;
    reg [ 4:0] nxtBlkOffset;
    reg [19:0] nxtTagWay1;
    reg [19:0] nxtTagWay2;
    reg [19:0] nxtTagWay3;
    reg [19:0] nxtTagWay4;
    reg [ 1:0] nxtLRUWay1;
    reg [ 1:0] nxtLRUWay2;
    reg [ 1:0] nxtLRUWay3;
    reg [ 1:0] nxtLRUWay4;
    reg        nxtValidWay1;
    reg        nxtValidWay2;
    reg        nxtValidWay3;
    reg        nxtValidWay4;
    reg        nxtICacheHitWay1;
    reg        nxtICacheHitWay2;
    reg        nxtICacheHitWay3;
    reg        nxtICacheHitWay4;

    wire [1:0] refillIndex;

    //stage Request Send reg:
    reg [ 1:0] rsRefillIndex;
    reg [31:0] rsAddr;

    assign busy = stage != FREE;

    always @(posedge clk) begin

        if (!resetn) begin
            stage <= FREE;
        end else begin
            //Free--(TLB hitted)-->TagOK.
            if ((stage == FREE) && tagValid && pgOffsetValid) begin
                stage    <= TAG_OK;
                tag      <= tagIn;
                pgOffset <= pgOffsetIn;
            end

            if (stage == TAG_OK) begin
                if (iCacheHit) begin
                    //TagOK--(i-cache hitted)-->Write control block.
                    stage        <= WR_CTRL;
                end else begin
                    //TagOK--(i-cache miss)-->Select.
                    stage <= SELECT;
                end

                //use for write back.
                nxtTag       <= tag;
                nxtIndex     <= index;
                nxtBlkOffset <= blkOffset;

                //use for generate control information writed back.
                nxtTagWay1 <= tagWay1;
                nxtTagWay2 <= tagWay2;
                nxtTagWay3 <= tagWay3;
                nxtTagWay4 <= tagWay4;

                //use for decided the refill way number.
                nxtValidWay1 <= validWay1;
                nxtValidWay2 <= validWay2;
                nxtValidWay3 <= validWay3;
                nxtValidWay4 <= validWay4;

                //use for calculate new LRU number.
                nxtLRUWay1  <= LRUWay1;
                nxtLRUWay2  <= LRUWay2;
                nxtLRUWay3  <= LRUWay3;
                nxtLRUWay4  <= LRUWay4;

                //use for check which way hitted.
                nxtICacheHitWay1 <= iCacheHitWay1;
                nxtICacheHitWay2 <= iCacheHitWay2;
                nxtICacheHitWay3 <= iCacheHitWay3;
                nxtICacheHitWay4 <= iCacheHitWay4;
            end

            //Write control block---->Free.
            if (stage == WR_CTRL) begin
                stage <= FREE;
            end

            //Select--(Write control block at the same time)-->Request send.
            if (stage == SELECT) begin
                stage         <= REQ_SND;
                rsRefillIndex <= refillIndex;
                rsAddr        <= {nxtTag, nxtIndex, nxtBlkOffset};
            end

            //Request send--(data requested and data block return simultaneously)-->Free.
            if (stage == REQ_SND && dataRequestedReady && data2ICacheBlkReady) begin
                stage <= FREE;
            end
        end
    end

    //Free stage: when pgOffset is ok, we should read control block.
    wire [ 6:0] preIndex;

    assign preIndex = pgOffsetIn[11:5];

    //TagOk stage: Look up control block to decided whether address hits i-cache.
    wire [95:0] ctrlBlkOut;

    assign index     = pgOffset[11:5];
    assign blkOffset = pgOffset[ 4:0];

    assign tagWay1 = ctrlBlkOut[19: 0];
    assign tagWay2 = ctrlBlkOut[43:24];
    assign tagWay3 = ctrlBlkOut[67:48];
    assign tagWay4 = ctrlBlkOut[91:72];

    assign validWay1 = ctrlBlkOut[22];
    assign validWay2 = ctrlBlkOut[46];
    assign validWay3 = ctrlBlkOut[70];
    assign validWay4 = ctrlBlkOut[94];

    assign LRUWay1 = ctrlBlkOut[21:20];
    assign LRUWay2 = ctrlBlkOut[45:44];
    assign LRUWay3 = ctrlBlkOut[69:68];
    assign LRUWay4 = ctrlBlkOut[93:92];

    assign iCacheHitWay1 = (tagWay1 == tag) & validWay1;
    assign iCacheHitWay2 = (tagWay2 == tag) & validWay2;
    assign iCacheHitWay3 = (tagWay3 == tag) & validWay3;
    assign iCacheHitWay4 = (tagWay4 == tag) & validWay4;

    assign iCacheHit = iCacheHitWay1 | iCacheHitWay2 | iCacheHitWay3 | iCacheHitWay4;

    //Select or Write control block stage: Calculate new LRU to write back or pass to next stage.
    wire       LRUWay1GT2;
    wire       LRUWay1GT3;
    wire       LRUWay1GT4;
    wire       LRUWay2GT3;
    wire       LRUWay2GT4;
    wire       LRUWay3GT4;
    wire [1:0] aRefillLRUWay1;
    wire [1:0] aRefillLRUWay2;
    wire [1:0] aRefillLRUWay3;
    wire [1:0] aRefillLRUWay4;
    wire [1:0] newLRUWay1;
    wire [1:0] newLRUWay2;
    wire [1:0] newLRUWay3;
    wire [1:0] newLRUWay4;

    assign LRUWay1GT2 = nxtLRUWay1 > nxtLRUWay2;
    assign LRUWay1GT3 = nxtLRUWay1 > nxtLRUWay3;
    assign LRUWay1GT4 = nxtLRUWay1 > nxtLRUWay4;
    assign LRUWay2GT3 = nxtLRUWay2 > nxtLRUWay3;
    assign LRUWay2GT4 = nxtLRUWay2 > nxtLRUWay4;
    assign LRUWay3GT4 = nxtLRUWay3 > nxtLRUWay4;

    assign refillIndex = //There is an empty way.
                         (!nxtValidWay1) ? 2'd0 :
                         (!nxtValidWay2) ? 2'd1 :
                         (!nxtValidWay3) ? 2'd2 :
                         (!nxtValidWay4) ? 2'd3 :
                         //All way is valid, need to refill a way.
                         ( LRUWay1GT2 &&  LRUWay1GT3 && LRUWay1GT4) ? 2'd0 :
                         (~LRUWay1GT2 &&  LRUWay2GT3 && LRUWay2GT4) ? 2'd1 :
                         (~LRUWay1GT3 && ~LRUWay2GT3 && LRUWay3GT4) ? 2'd2 :
                                                                      2'd3 ;

    assign aRefillLRUWay1 = (refillIndex == 2'd0) ? 2'd0 : nxtLRUWay1 + 2'd1;
    assign aRefillLRUWay2 = (refillIndex == 2'd1) ? 2'd0 : nxtLRUWay2 + 2'd1;
    assign aRefillLRUWay3 = (refillIndex == 2'd2) ? 2'd0 : nxtLRUWay3 + 2'd1;
    assign aRefillLRUWay4 = (refillIndex == 2'd3) ? 2'd0 : nxtLRUWay4 + 2'd1;

    assign newLRUWay1 = (nxtICacheHitWay1) ?                     2'd0 :
                        (nxtICacheHitWay2) ? nxtLRUWay1 + ~LRUWay1GT2 :
                        (nxtICacheHitWay3) ? nxtLRUWay1 + ~LRUWay1GT3 :
                        (nxtICacheHitWay4) ? nxtLRUWay1 + ~LRUWay1GT4 :
                                                       aRefillLRUWay1 ;
    assign newLRUWay2 = (nxtICacheHitWay1) ? nxtLRUWay2 +  LRUWay1GT2 :
                        (nxtICacheHitWay2) ?                     2'd0 :
                        (nxtICacheHitWay3) ? nxtLRUWay2 + ~LRUWay2GT3 :
                        (nxtICacheHitWay4) ? nxtLRUWay2 + ~LRUWay2GT4 :
                                                       aRefillLRUWay2 ;
    assign newLRUWay3 = (nxtICacheHitWay1) ? nxtLRUWay3 +  LRUWay1GT3 :
                        (nxtICacheHitWay2) ? nxtLRUWay3 +  LRUWay2GT3 :
                        (nxtICacheHitWay3) ?                     2'd0 :
                        (nxtICacheHitWay4) ? nxtLRUWay3 + ~LRUWay3GT4 :
                                                       aRefillLRUWay3 ;
    assign newLRUWay4 = (nxtICacheHitWay1) ? nxtLRUWay4 +  LRUWay1GT4 :
                        (nxtICacheHitWay2) ? nxtLRUWay4 +  LRUWay2GT4 :
                        (nxtICacheHitWay3) ? nxtLRUWay4 +  LRUWay3GT4 :
                        (nxtICacheHitWay4) ?                     2'd0 :
                                                       aRefillLRUWay4 ;

    //Select or Write control block stage: generate new control state to write back.
    wire        newValidWay1;
    wire        newValidWay2;
    wire        newValidWay3;
    wire        newValidWay4;
    wire [19:0] newTagWay1;
    wire [19:0] newTagWay2;
    wire [19:0] newTagWay3;
    wire [19:0] newTagWay4;
    wire [95:0] newCtrl;

    assign newValidWay1 = (stage == SELECT && refillIndex == 2'd0) ? 1'd1 : nxtValidWay1;
    assign newValidWay2 = (stage == SELECT && refillIndex == 2'd1) ? 1'd1 : nxtValidWay2;
    assign newValidWay3 = (stage == SELECT && refillIndex == 2'd2) ? 1'd1 : nxtValidWay3;
    assign newValidWay4 = (stage == SELECT && refillIndex == 2'd3) ? 1'd1 : nxtValidWay4;

    assign newTagWay1 = (stage == SELECT && refillIndex == 2'd0) ? nxtTag : nxtTagWay1;
    assign newTagWay2 = (stage == SELECT && refillIndex == 2'd1) ? nxtTag : nxtTagWay2;
    assign newTagWay3 = (stage == SELECT && refillIndex == 2'd2) ? nxtTag : nxtTagWay3;
    assign newTagWay4 = (stage == SELECT && refillIndex == 2'd3) ? nxtTag : nxtTagWay4;

    assign newCtrl = {1'd0, newValidWay4, newLRUWay4, newTagWay4,
                      1'd0, newValidWay3, newLRUWay3, newTagWay3,
                      1'd0, newValidWay2, newLRUWay2, newTagWay2,
                      1'd0, newValidWay1, newLRUWay1, newTagWay1};

    //Request send stage: Prepare the output signal.
    assign addr2Cache2 = {rsAddr[31:5], 5'd0};
    assign addr2Cache2Valid = stage == REQ_SND;

    //control ram
    wire       ctrlBlkWrite;
    wire       ctrlBlkRead;
    wire [6:0] ctrlBlkAddr;

    assign ctrlBlkWrite  = (stage == WR_CTRL) | (stage == SELECT);
    assign ctrlBlkRead   = ((stage == FREE) && pgOffsetValid);
    assign ctrlBlkAddr   = (!ctrlBlkRead) ? nxtIndex : preIndex;

    ctrlBlk iCacheCtrlBlk(
        .clka (                       clk),
        .ena  (ctrlBlkRead | ctrlBlkWrite),
        .wea  (              ctrlBlkWrite),
        .addra(               ctrlBlkAddr),
        .dina (                   newCtrl),
        .douta(                ctrlBlkOut)
    );

    //data ram
    wire [127:0] dataOutFromICacheFull;
    wire [ 31:0] dataOutFromCache2;
    wire         dataBlkWrite;
    wire         dataBlkRead;
    wire [  6:0] dataBlkAddr;
    wire [ 15:0] dataBlkWrByteEn;
    wire [127:0] dataBlkOut1;
    wire [127:0] dataBlkOut2;
    wire [127:0] dataBlkOut3;
    wire [127:0] dataBlkOut4;
    wire [127:0] dataBlkOut5;
    wire [127:0] dataBlkOut6;
    wire [127:0] dataBlkOut7;
    wire [127:0] dataBlkOut8;

    assign dataOutFromICacheFull = (blkOffset[4:2] == 3'd0) ? dataBlkOut1 :
                                   (blkOffset[4:2] == 3'd1) ? dataBlkOut2 :
                                   (blkOffset[4:2] == 3'd2) ? dataBlkOut3 :
                                   (blkOffset[4:2] == 3'd3) ? dataBlkOut4 :
                                   (blkOffset[4:2] == 3'd4) ? dataBlkOut5 :
                                   (blkOffset[4:2] == 3'd5) ? dataBlkOut6 :
                                   (blkOffset[4:2] == 3'd6) ? dataBlkOut7 :
                                                              dataBlkOut8 ;
    assign dataOutFromCache2     = (rsAddr[4:2] == 3'd0) ? data2ICacheBlk1 :
                                   (rsAddr[4:2] == 3'd1) ? data2ICacheBlk2 :
                                   (rsAddr[4:2] == 3'd2) ? data2ICacheBlk3 :
                                   (rsAddr[4:2] == 3'd3) ? data2ICacheBlk4 :
                                   (rsAddr[4:2] == 3'd4) ? data2ICacheBlk5 :
                                   (rsAddr[4:2] == 3'd5) ? data2ICacheBlk6 :
                                   (rsAddr[4:2] == 3'd6) ? data2ICacheBlk7 :
                                                           data2ICacheBlk8 ;
    assign dataOut               = (stage != TAG_OK) ? dataOutFromCache2 :
                                   //TagOK stage: need to select which way.
                                   (iCacheHitWay1) ? dataOutFromICacheFull[ 31: 0] :
                                   (iCacheHitWay2) ? dataOutFromICacheFull[ 63:32] :
                                   (iCacheHitWay3) ? dataOutFromICacheFull[ 95:64] :
                                                     dataOutFromICacheFull[127:96] ;
    assign dataOutReady          = (stage == TAG_OK && iCacheHit) || (stage == REQ_SND && dataRequestedReady && data2ICacheBlkReady);

    assign dataBlkWrite  = (stage == REQ_SND && dataRequestedReady && data2ICacheBlkReady);
    assign dataBlkRead   = (stage == FREE) & pgOffsetValid;
    assign dataBlkAddr   = (!dataBlkRead) ? rsAddr[11:5] : preIndex;
    assign dataBlkWrByteEn = (!dataBlkWrite) ? 16'd0 :
                             //need to refill one way
                             (rsRefillIndex == 2'd0) ? 16'h000f :
                             (rsRefillIndex == 2'd1) ? 16'h00f0 :
                             (rsRefillIndex == 2'd2) ? 16'h0f00 :
                                                       16'hf000 ;

    dataBlk_128X128 iCacheDataBlk1(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk1}}),
        .douta(               dataBlkOut1)
    );

    dataBlk_128X128 iCacheDataBlk2(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk2}}),
        .douta(               dataBlkOut2)
    );

    dataBlk_128X128 iCacheDataBlk3(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk3}}),
        .douta(               dataBlkOut3)
    );

    dataBlk_128X128 iCacheDataBlk4(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk4}}),
        .douta(               dataBlkOut4)
    );

    dataBlk_128X128 iCacheDataBlk5(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk5}}),
        .douta(               dataBlkOut5)
    );

    dataBlk_128X128 iCacheDataBlk6(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk6}}),
        .douta(               dataBlkOut6)
    );

    dataBlk_128X128 iCacheDataBlk7(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk7}}),
        .douta(               dataBlkOut7)
    );

    dataBlk_128X128 iCacheDataBlk8(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWrite),
        .wea  (           dataBlkWrByteEn),
        .addra(               dataBlkAddr),
        .dina (      {4{data2ICacheBlk8}}),
        .douta(               dataBlkOut8)
    );

endmodule
