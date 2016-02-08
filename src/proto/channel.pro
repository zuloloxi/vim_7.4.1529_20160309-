/* channel.c */
void channel_gui_register_all(void);
int channel_open(char *hostname, int port_in, int waittime, void (*close_cb)(void));
void channel_set_json_mode(int idx, ch_mode_T ch_mode);
void channel_set_timeout(int idx, int timeout);
void channel_set_callback(int idx, char_u *callback);
void channel_set_req_callback(int idx, char_u *callback, int id);
char_u *channel_get(int idx);
int channel_collapse(int idx);
int channel_is_open(int idx);
void channel_close(int idx);
int channel_save(int idx, char_u *buf, int len);
char_u *channel_peek(int idx);
void channel_clear(int idx);
int channel_get_id(void);
void channel_read(int idx);
char_u *channel_read_block(int idx);
int channel_read_json_block(int ch_idx, int id, typval_T **rettv);
int channel_socket2idx(sock_T fd);
int channel_send(int idx, char_u *buf, char *fun);
int channel_poll_setup(int nfd_in, void *fds_in);
int channel_poll_check(int ret_in, void *fds_in);
int channel_select_setup(int maxfd_in, void *rfds_in);
int channel_select_check(int ret_in, void *rfds_in);
int channel_parse_messages(void);
int set_ref_in_channel(int copyID);
ch_mode_T channel_get_mode(int idx);
/* vim: set ft=c : */
