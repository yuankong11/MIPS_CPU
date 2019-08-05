module dcache(
    input         clk,
    input         resetn,

    input  [11:0] pgOffsetIn,
    input         pgOffsetValid,
    input  [19:0] tagIn,
    input         tagValid,
    input         wrIn,
    input  [3:0]  wstrbIn,
    input  [31:0] wdataIn,

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

    output         dataWriteBackValid,
    input          dataWriteBackAck,
    output [31:0]  dataWriteBackAddr,
    output [255:0] dataWriteBack,

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
    parameter WRITE_BACK = 9;

    //State machine.
    //Global reg:
    reg [4:0] stage;

    //stage TagOK reg:
    reg [ 19:0] tag;
    reg [ 11:0] pgOffset;

    reg wr;
    reg [3:0]  wstrb;
    reg [31:0] wdata;

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
    wire        dirtyWay1;
    wire        dirtyWay2;
    wire        dirtyWay3;
    wire        dirtyWay4;
    wire        iCacheHitWay1;
    wire        iCacheHitWay2;
    wire        iCacheHitWay3;
    wire        iCacheHitWay4;
    wire        iCacheHit;

    reg [31:0] valid [15:0];
    wire [31:0] wayValids;
    wire [3:0] wayValid;
    wire [31:0] newWayValids;

    wire        needWriteBack;

    //stage Write Control & Select reg:
    reg [19:0] nxtTag;
    reg [ 6:0] nxtIndex;
    reg [ 4:0] nxtBlkOffset;
    reg [31:0] nxtWayValids;
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
    reg        nxtDirtyWay1;
    reg        nxtDirtyWay2;
    reg        nxtDirtyWay3;
    reg        nxtDirtyWay4;
    reg        nxtICacheHitWay1;
    reg        nxtICacheHitWay2;
    reg        nxtICacheHitWay3;
    reg        nxtICacheHitWay4;

    wire [1:0] refillIndex;

    //stage Request Send reg:
    reg [ 1:0] rsRefillIndex;
    reg [31:0] rsAddr;

    reg noWrCtrl;

    assign busy = stage != FREE;

    always @(posedge clk) begin

        if (!resetn) begin
            stage    <= FREE;
            noWrCtrl <= 1'b0;
        end else begin
            //Free--(TLB hitted)-->TagOK.
            if ((stage == FREE) && tagValid && pgOffsetValid) begin
                stage       <= TAG_OK;
                tag         <= tagIn;
                pgOffset    <= pgOffsetIn;
                wr          <= wrIn;
                wstrb       <= wstrbIn;
                wdata       <= wdataIn;
            end

            if (stage == TAG_OK) begin
                if (iCacheHit) begin
                    //TagOK--(i-cache hitted)-->Write control block.
                    if(noWrCtrl) begin
                        stage    <= FREE;
                        noWrCtrl <= 1'b0;
                    end else begin
                        stage <= WR_CTRL;
                    end
                end else begin
                    //TagOK--(i-cache miss)-->Select.
                    stage <= SELECT;
                end

                //use for write back.
                nxtTag       <= tag;
                nxtIndex     <= index;
                nxtBlkOffset <= blkOffset;
                nxtWayValids <= wayValids;

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

                nxtDirtyWay1 <= dirtyWay1;
                nxtDirtyWay2 <= dirtyWay2;
                nxtDirtyWay3 <= dirtyWay3;
                nxtDirtyWay4 <= dirtyWay4;

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
                rsRefillIndex <= refillIndex;
                rsAddr        <= {nxtTag, nxtIndex, nxtBlkOffset};
                if(needWriteBack) begin
                    stage <= WRITE_BACK;
                end else begin
                    stage <= REQ_SND;
                end
            end

            if (stage == WRITE_BACK && dataWriteBackAck) begin
                stage <= REQ_SND;
            end

            //Request send--(data requested and data block return simultaneously)-->Free.
            if (stage == REQ_SND && dataRequestedReady && data2ICacheBlkReady) begin
                stage    <= TAG_OK;
                noWrCtrl <= 1'b1;
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

    //control ram
    wire       ctrlBlkWrite;
    wire       ctrlBlkRead;
    wire [6:0] ctrlBlkAddr;

    always @(posedge clk) begin
        if (!resetn) begin
            valid[0] <= 16'd0;
            valid[1] <= 16'd0;
            valid[2] <= 16'd0;
            valid[3] <= 16'd0;
            valid[4] <= 16'd0;
            valid[5] <= 16'd0;
            valid[6] <= 16'd0;
            valid[7] <= 16'd0;
            valid[8] <= 16'd0;
            valid[9] <= 16'd0;
            valid[10] <= 16'd0;
            valid[11] <= 16'd0;
            valid[12] <= 16'd0;
            valid[13] <= 16'd0;
            valid[14] <= 16'd0;
            valid[15] <= 16'd0;
        end else if (ctrlBlkWrite) begin
            valid[index[6:3]] <= newWayValids;
        end
    end

    assign wayValids = valid[index[6:3]];
    assign wayValid = (index[2:0] == 3'd0) ? wayValids[3:0] :
                      (index[2:0] == 3'd1) ? wayValids[7:4] :
                      (index[2:0] == 3'd2) ? wayValids[11:8] :
                      (index[2:0] == 3'd3) ? wayValids[15:12] :
                      (index[2:0] == 3'd4) ? wayValids[19:16] :
                      (index[2:0] == 3'd5) ? wayValids[23:20] :
                      (index[2:0] == 3'd6) ? wayValids[27:24] :
                      wayValids[31:28];

    assign validWay1 = wayValid[0];
    assign validWay2 = wayValid[1];
    assign validWay3 = wayValid[2];
    assign validWay4 = wayValid[3];

    assign dirtyWay1 = ctrlBlkOut[23];
    assign dirtyWay2 = ctrlBlkOut[47];
    assign dirtyWay3 = ctrlBlkOut[71];
    assign dirtyWay4 = ctrlBlkOut[95];

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

    wire newDirtyWay1 = ((stage == SELECT && refillIndex == 2'd0) || (stage == WR_CTRL && nxtIndex == 2'd0)) ? wr : nxtDirtyWay1;
    wire newDirtyWay2 = ((stage == SELECT && refillIndex == 2'd1) || (stage == WR_CTRL && nxtIndex == 2'd1)) ? wr : nxtDirtyWay2;
    wire newDirtyWay3 = ((stage == SELECT && refillIndex == 2'd2) || (stage == WR_CTRL && nxtIndex == 2'd2)) ? wr : nxtDirtyWay3;
    wire newDirtyWay4 = ((stage == SELECT && refillIndex == 2'd3) || (stage == WR_CTRL && nxtIndex == 2'd3)) ? wr : nxtDirtyWay4;

    assign newCtrl = {wr, newValidWay4, newLRUWay4, newTagWay4,
                      wr, newValidWay3, newLRUWay3, newTagWay3,
                      wr, newValidWay2, newLRUWay2, newTagWay2,
                      wr, newValidWay1, newLRUWay1, newTagWay1};

    wire [3:0] newWayValid;

    assign newWayValid = {newValidWay4, newValidWay3, newValidWay2, newValidWay1};
    assign newWayValids = (index[2:0] == 3'd0) ? {nxtWayValids[31:4], newWayValid} :
                          (index[2:0] == 3'd1) ? {nxtWayValids[31:8], newWayValid, nxtWayValids[3:0]} :
                          (index[2:0] == 3'd2) ? {nxtWayValids[31:12], newWayValid, nxtWayValids[7:0]} :
                          (index[2:0] == 3'd3) ? {nxtWayValids[31:16], newWayValid, nxtWayValids[11:0]} :
                          (index[2:0] == 3'd4) ? {nxtWayValids[31:20], newWayValid, nxtWayValids[15:0]} :
                          (index[2:0] == 3'd5) ? {nxtWayValids[31:24], newWayValid, nxtWayValids[19:0]} :
                          (index[2:0] == 3'd6) ? {nxtWayValids[31:28], newWayValid, nxtWayValids[23:0]} :
                          {newWayValid, nxtWayValids[27:0]};

    assign needWriteBack = (stage == SELECT) &&
                           (nxtValidWay1 && refillIndex == 2'd0 && nxtDirtyWay1) ||
                           (nxtValidWay2 && refillIndex == 2'd1 && nxtDirtyWay2) ||
                           (nxtValidWay3 && refillIndex == 2'd2 && nxtDirtyWay3) ||
                           (nxtValidWay4 && refillIndex == 2'd3 && nxtDirtyWay4) ;
    assign dataWriteBackValid = (stage == WRITE_BACK);
    wire [127:0] dataBlkOut1;
    wire [127:0] dataBlkOut2;
    wire [127:0] dataBlkOut3;
    wire [127:0] dataBlkOut4;
    wire [127:0] dataBlkOut5;
    wire [127:0] dataBlkOut6;
    wire [127:0] dataBlkOut7;
    wire [127:0] dataBlkOut8;
    wire [255:0] dataWay[3:0];
    assign dataWay[0] = {dataBlkOut1[31 : 0], dataBlkOut2[31 : 0],
                         dataBlkOut3[31 : 0], dataBlkOut4[31 : 0],
                         dataBlkOut5[31 : 0], dataBlkOut6[31 : 0],
                         dataBlkOut7[31 : 0], dataBlkOut8[31 : 0]};
    assign dataWay[1] = {dataBlkOut1[63 : 32], dataBlkOut2[63 : 32],
                         dataBlkOut3[63 : 32], dataBlkOut4[63 : 32],
                         dataBlkOut5[63 : 32], dataBlkOut6[63 : 32],
                         dataBlkOut7[63 : 32], dataBlkOut8[63 : 32]};
    assign dataWay[2] = {dataBlkOut1[95 : 64], dataBlkOut2[95 : 64],
                         dataBlkOut3[95 : 64], dataBlkOut4[95 : 64],
                         dataBlkOut5[95 : 64], dataBlkOut6[95 : 64],
                         dataBlkOut7[95 : 64], dataBlkOut8[95 : 64]};
    assign dataWay[3] = {dataBlkOut1[127 : 96], dataBlkOut2[127 : 96],
                         dataBlkOut3[127 : 96], dataBlkOut4[127 : 96],
                         dataBlkOut5[127 : 96], dataBlkOut6[127 : 96],
                         dataBlkOut7[127 : 96], dataBlkOut8[127 : 96]};
    reg [255:0] dataWriteBackReg;
    always @(posedge clk)
    begin
        if(stage == TAG_OK)
            dataWriteBackReg <= (refillIndex == 2'd0 && dataWay[0]) ||
                                (refillIndex == 2'd1 && dataWay[1]) ||
                                (refillIndex == 2'd2 && dataWay[2]) ||
                                (refillIndex == 2'd3 && dataWay[3]) ;
    end
    assign dataWriteBack = dataWriteBackReg;
    wire [19:0] writeBackTag = refillIndex == 2'd0 ? nxtTagWay1 :
                               refillIndex == 2'd1 ? nxtTagWay2 :
                               refillIndex == 2'd2 ? nxtTagWay3 :
                                                     nxtTagWay4 ;
    assign dataWriteBackAddr = {writeBackTag, nxtIndex, 5'd0};

    //Request send stage: Prepare the output signal.
    assign addr2Cache2 = {rsAddr[31:5], 5'd0};
    assign addr2Cache2Valid = stage == REQ_SND;

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
    wire         dataBlkRead;
    wire [  6:0] dataBlkAddr;
    wire [ 15:0] dataBlkWrByteEn;

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
    assign dataOut               = (iCacheHitWay1) ? dataOutFromICacheFull[ 31: 0] :
                                   (iCacheHitWay2) ? dataOutFromICacheFull[ 63:32] :
                                   (iCacheHitWay3) ? dataOutFromICacheFull[ 95:64] :
                                                     dataOutFromICacheFull[127:96] ;
    assign dataOutReady          = (stage == TAG_OK && iCacheHit);

    wire dataBlkWriteIn = (stage == TAG_OK) && wr;
    wire [7:0] dataBlkWrSel = {8{dataBlkWriteIn}} &
                              {blkOffset[4:2] == 3'd7,
                               blkOffset[4:2] == 3'd6,
                               blkOffset[4:2] == 3'd5,
                               blkOffset[4:2] == 3'd4,
                               blkOffset[4:2] == 3'd3,
                               blkOffset[4:2] == 3'd2,
                               blkOffset[4:2] == 3'd1,
                               blkOffset[4:2] == 3'd0};

    wire [15:0] dataBlkWstrb = ((iCacheHitWay1) ? 16'h000f :
                                (iCacheHitWay2) ? 16'h00f0 :
                                (iCacheHitWay3) ? 16'h0f00 :
                                16'hf000 ) & {4{wstrb}};

    wire [15:0] dataBlkWrByteEnIn[7:0];
    assign dataBlkWrByteEnIn[0] = dataBlkWstrb & {16{dataBlkWrSel[0]}};
    assign dataBlkWrByteEnIn[1] = dataBlkWstrb & {16{dataBlkWrSel[1]}};
    assign dataBlkWrByteEnIn[2] = dataBlkWstrb & {16{dataBlkWrSel[2]}};
    assign dataBlkWrByteEnIn[3] = dataBlkWstrb & {16{dataBlkWrSel[3]}};
    assign dataBlkWrByteEnIn[4] = dataBlkWstrb & {16{dataBlkWrSel[4]}};
    assign dataBlkWrByteEnIn[5] = dataBlkWstrb & {16{dataBlkWrSel[5]}};
    assign dataBlkWrByteEnIn[6] = dataBlkWstrb & {16{dataBlkWrSel[6]}};
    assign dataBlkWrByteEnIn[7] = dataBlkWstrb & {16{dataBlkWrSel[7]}};

    wire [31:0] dataBlkWdata1 = (stage == REQ_SND) ? data2ICacheBlk1 : wdata;
    wire [31:0] dataBlkWdata2 = (stage == REQ_SND) ? data2ICacheBlk2 : wdata;
    wire [31:0] dataBlkWdata3 = (stage == REQ_SND) ? data2ICacheBlk3 : wdata;
    wire [31:0] dataBlkWdata4 = (stage == REQ_SND) ? data2ICacheBlk4 : wdata;
    wire [31:0] dataBlkWdata5 = (stage == REQ_SND) ? data2ICacheBlk5 : wdata;
    wire [31:0] dataBlkWdata6 = (stage == REQ_SND) ? data2ICacheBlk6 : wdata;
    wire [31:0] dataBlkWdata7 = (stage == REQ_SND) ? data2ICacheBlk7 : wdata;
    wire [31:0] dataBlkWdata8 = (stage == REQ_SND) ? data2ICacheBlk8 : wdata;

    wire   dataBlkWriteAlloc = (stage == REQ_SND && dataRequestedReady && data2ICacheBlkReady);
    assign dataBlkRead   = (stage == FREE) && pgOffsetValid;
    assign dataBlkAddr   = (!dataBlkRead) ? ((stage == REQ_SND) ? rsAddr[11:5] : index) : preIndex;
    assign dataBlkWrByteEn = (!dataBlkWriteAlloc) ? 16'd0 :
                             //need to refill one way
                             (rsRefillIndex == 2'd0) ? 16'h000f :
                             (rsRefillIndex == 2'd1) ? 16'h00f0 :
                             (rsRefillIndex == 2'd2) ? 16'h0f00 :
                                                       16'hf000 ;

    dataBlk_128X128 iCacheDataBlk1(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[0]),
        .addra(               dataBlkAddr),
        .dina (        {4{dataBlkWdata1}}),
        .douta(               dataBlkOut1)
    );

    dataBlk_128X128 iCacheDataBlk2(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[1]),
        .addra(               dataBlkAddr),
        .dina (       {4{dataBlkWdata2}}),
        .douta(               dataBlkOut2)
    );

    dataBlk_128X128 iCacheDataBlk3(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[2]),
        .addra(               dataBlkAddr),
        .dina (       {4{dataBlkWdata3}}),
        .douta(               dataBlkOut3)
    );

    dataBlk_128X128 iCacheDataBlk4(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[3]),
        .addra(               dataBlkAddr),
        .dina (       {4{dataBlkWdata4}}),
        .douta(               dataBlkOut4)
    );

    dataBlk_128X128 iCacheDataBlk5(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[4]),
        .addra(               dataBlkAddr),
        .dina (       {4{dataBlkWdata5}}),
        .douta(               dataBlkOut5)
    );

    dataBlk_128X128 iCacheDataBlk6(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[5]),
        .addra(               dataBlkAddr),
        .dina (       {4{dataBlkWdata6}}),
        .douta(               dataBlkOut6)
    );

    dataBlk_128X128 iCacheDataBlk7(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[6]),
        .addra(               dataBlkAddr),
        .dina (       {4{dataBlkWdata7}}),
        .douta(               dataBlkOut7)
    );

    dataBlk_128X128 iCacheDataBlk8(
        .clka (                       clk),
        .ena  (dataBlkRead | dataBlkWriteAlloc | dataBlkWriteIn),
        .wea  (           dataBlkWrByteEn | dataBlkWrByteEnIn[7]),
        .addra(               dataBlkAddr),
        .dina (       {4{dataBlkWdata8}}),
        .douta(               dataBlkOut8)
    );

endmodule
