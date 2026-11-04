/* Included in ris_controller.c: shares its bounded waits and hidden apply_raw. */
void ris_qam_cancel_upload(ris_controller *d)
{
    unsigned i;
    d->qam_uploading=d->qam_counts_set=0;d->qam_crc=0xffffffffu;d->qam_expected_crc=0;
    for(i=0;i<3;++i)d->qam_expected[i]=0;
    for(i=0;i<4;++i)d->qam_loaded[i]=0;
}
u32 ris_qam_received(const ris_controller *d)
{return d->qam_loaded[0]+d->qam_loaded[1]+d->qam_loaded[2]+d->qam_loaded[3];}
u32 ris_qam_expected_bytes(const ris_controller *d)
{return d->qam_expected[0]*52u+d->qam_expected[1]*4u+1024u+d->qam_expected[2];}
static u32 qam_crc_bytes(u32 crc,const u8 *p,u32 n)
{
    u32 i,b;for(i=0;i<n;++i){crc^=p[i];for(b=0;b<8;++b)crc=(crc>>1)^((0u-(crc&1u))&0xedb88320u);}
    return crc;
}
static void qam_crc_word(ris_controller *d,u32 value)
{
    u8 p[4];unsigned i;for(i=0;i<4;++i)p[i]=(u8)(value>>(8*i));
    d->qam_crc=qam_crc_bytes(d->qam_crc,p,4);
}
static int qam_control(ris_controller *d,u32 value)
{
    XTime start;XTime_GetTime(&start);
    while(ris_read(d,RIS_QAM_STATUS)&RIS_QAM_PENDING)if(expired(start))return RIS_TIMEOUT;
    ris_write(d,RIS_QAM_CONTROL,value);barrier();
    while(ris_read(d,RIS_QAM_STATUS)&RIS_QAM_PENDING)if(expired(start))return RIS_TIMEOUT;
    return RIS_OK;
}
int ris_qam_stop(ris_controller *d)
{
    u32 s,n,w;u8 image[50];int rc;XTime start;
    ris_qam_cancel_upload(d);
    if(!d->qam_supported)return RIS_OK;
    s=ris_read(d,RIS_QAM_STATUS);
    if(!(s&(RIS_QAM_OWNED|RIS_QAM_RUNNING|RIS_QAM_PREFLIGHT|RIS_QAM_PENDING)))return RIS_OK;
    rc=qam_control(d,RIS_QAM_STOP);if(rc)return rc;
    XTime_GetTime(&start);
    while(ris_read(d,RIS_QAM_STATUS)&(RIS_QAM_RUNNING|RIS_QAM_PREFLIGHT|RIS_QAM_PENDING))
        if(expired(start))return RIS_TIMEOUT;
    if(!(ris_read(d,RIS_QAM_STATUS)&RIS_QAM_OWNED))return RIS_OK;
    /* Match all 400 bits in the normal engine while its clocks are hidden. */
    for(n=0;n<13;++n){w=ris_read(d,RIS_QAM_HELD_FRAME+n*4);unsigned b;
        for(b=0;b<4 && n*4+b<50;++b)image[n*4+b]=(u8)(w>>(8*b));}
    rc=apply_raw(d,image,0x3ffffffffffffULL);if(rc)return rc;
    rc=qam_control(d,RIS_QAM_RELEASE);if(rc)return rc;
    return (ris_read(d,RIS_QAM_STATUS)&RIS_QAM_OWNED) ? RIS_HARDWARE_ERROR : RIS_OK;
}
int ris_qam_begin(ris_controller *d,u32 ticks,u32 k,u32 slots,u32 loop)
{
    int rc;
    if(!d->qam_supported || ticks<60 || ticks>1000000 || !k || k>1000000 || !slots || slots>65535 || loop>1)
        return RIS_NOT_ACCEPTED;
    rc=ris_fast_stop(d);if(rc)return rc;
    ris_mt_cancel_upload(d);ris_qam_cancel_upload(d);
    if(ris_read(d,RIS_QAM_STATUS)&15u)return RIS_HARDWARE_ERROR;
    ris_write(d,RIS_QAM_CONTROL,RIS_QAM_CLEAR_UPLOAD);
    ris_write(d,RIS_QAM_SLOT_TICKS,ticks);ris_write(d,RIS_QAM_REPEATS,k);ris_write(d,RIS_QAM_PERIOD_SLOTS,slots);barrier();
    if(ris_read(d,RIS_QAM_FRAME_COUNT)||ris_read(d,RIS_QAM_EVENT_COUNT)||ris_read(d,RIS_QAM_SYMBOL_COUNT)||ris_read(d,RIS_QAM_PAYLOAD_COUNT)||
       ris_read(d,RIS_QAM_SLOT_TICKS)!=ticks || ris_read(d,RIS_QAM_REPEATS)!=k || ris_read(d,RIS_QAM_PERIOD_SLOTS)!=slots)
        return RIS_HARDWARE_ERROR;
    d->qam_ticks=ticks;d->qam_k=k;d->qam_slots=slots;d->qam_loop=loop;d->qam_uploading=1;
    return RIS_OK;
}
int ris_qam_counts(ris_controller *d,u32 frames,u32 events,u32 bytes,u32 crc)
{
    if(!d->qam_uploading || d->qam_counts_set || !frames || frames>2048 || !events || events>32768 || !bytes || bytes>4096)
        return RIS_NOT_ACCEPTED;
    d->qam_expected[0]=frames;d->qam_expected[1]=events;d->qam_expected[2]=bytes;d->qam_expected_crc=crc;
    qam_crc_word(d,d->qam_ticks);qam_crc_word(d,d->qam_k);qam_crc_word(d,d->qam_slots);qam_crc_word(d,d->qam_loop);
    qam_crc_word(d,frames);qam_crc_word(d,events);qam_crc_word(d,bytes);d->qam_counts_set=1;
    return RIS_OK;
}
int ris_qam_data(ris_controller *d,unsigned kind,u32 offset,const u8 *data,u32 bytes)
{
    u32 size[4],address[4]={RIS_QAM_FRAME_DATA,RIS_QAM_EVENT_DATA,RIS_QAM_SYMBOL_DATA,RIS_QAM_PAYLOAD_DATA};
    u32 i,n,word=0,s,actual;
    if(!d->qam_uploading || !d->qam_counts_set || kind>3 || !data || !bytes || bytes>48)return RIS_NOT_ACCEPTED;
    size[0]=d->qam_expected[0]*52u;size[1]=d->qam_expected[1]*4u;size[2]=1024;size[3]=d->qam_expected[2];
    if(offset!=d->qam_loaded[kind] || offset>size[kind] || bytes>size[kind]-offset || (kind<3 && bytes%4))goto bad;
    for(i=0;i<4;++i)if((i<kind && d->qam_loaded[i]!=size[i]) || (i>kind && d->qam_loaded[i]))goto bad;
    if(ris_read(d,RIS_QAM_STATUS)&15u)goto bad;
    /* Validate the complete packet before issuing any MMIO write. */
    if(kind<3)for(n=0;n<bytes;n+=4){
        word=(u32)data[n]|((u32)data[n+1]<<8)|((u32)data[n+2]<<16)|((u32)data[n+3]<<24);
        if(kind==0 && ((offset+n)/4)%13==12 && word>>16)goto bad;
        if(kind==1 && ((word&65535u)>=d->qam_expected[0] || !(word>>16)))goto bad;
        if(kind==2 && (!(word>>16) || (word&65535u)+(word>>16)>d->qam_expected[1]))goto bad;
    }
    for(n=0;n<bytes;n+=(kind==3 ? 1u : 4u)){
        word=data[n];if(kind<3)word|=((u32)data[n+1]<<8)|((u32)data[n+2]<<16)|((u32)data[n+3]<<24);
        ris_write(d,address[kind],word);
    }
    barrier();s=d->qam_loaded[kind]+bytes;
    if(kind==0){actual=ris_read(d,RIS_QAM_FRAME_COUNT);if((actual&4095u)!=s/52u || (actual>>12)!=(s%52u)/4u)goto hardware;}
    else if(ris_read(d,kind==1 ? RIS_QAM_EVENT_COUNT : kind==2 ? RIS_QAM_SYMBOL_COUNT : RIS_QAM_PAYLOAD_COUNT)!=(kind==3 ? s : s/4))goto hardware;
    d->qam_loaded[kind]=s;d->qam_crc=qam_crc_bytes(d->qam_crc,data,bytes);return RIS_OK;
hardware:ris_qam_cancel_upload(d);return RIS_HARDWARE_ERROR;
bad:ris_qam_cancel_upload(d);return RIS_NOT_ACCEPTED;
}
int ris_qam_start(ris_controller *d,u32 crc)
{
    u32 s;int rc;XTime start;
    if(!d->qam_uploading || !d->qam_counts_set || crc!=d->qam_expected_crc || (d->qam_crc^0xffffffffu)!=crc ||
       d->qam_loaded[0]!=d->qam_expected[0]*52u || d->qam_loaded[1]!=d->qam_expected[1]*4u ||
       d->qam_loaded[2]!=1024 || d->qam_loaded[3]!=d->qam_expected[2]){ris_qam_cancel_upload(d);return RIS_NOT_ACCEPTED;}
    if(ris_read(d,RIS_QAM_FRAME_COUNT)!=d->qam_expected[0] || ris_read(d,RIS_QAM_EVENT_COUNT)!=d->qam_expected[1] ||
       ris_read(d,RIS_QAM_SYMBOL_COUNT)!=256 || ris_read(d,RIS_QAM_PAYLOAD_COUNT)!=d->qam_expected[2]){ris_qam_cancel_upload(d);return RIS_HARDWARE_ERROR;}
    /* Enabling OE does not stop or alter normal/fast clocks. Current image is held. */
    rc=ris_output_enable(d,1);if(rc)return rc;
    rc=qam_control(d,d->qam_loop ? RIS_QAM_LOOP : RIS_QAM_ONCE);if(rc)return rc;
    XTime_GetTime(&start);
    do {s=ris_read(d,RIS_QAM_STATUS);if(expired(start)){(void)ris_qam_stop(d);return RIS_TIMEOUT;}}
    while(s&(RIS_QAM_PREFLIGHT|RIS_QAM_PENDING));
    d->qam_uploading=d->qam_counts_set=0;
    if(!(s&RIS_QAM_OWNED) || ris_read(d,RIS_QAM_ERROR))return RIS_HARDWARE_ERROR;
    d->qam_active_crc=crc;return RIS_OK;
}
