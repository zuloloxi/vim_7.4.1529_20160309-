" Test for channel functions.
scriptencoding utf-8

if !has('channel')
  finish
endif

" This test requires the Python command to run the test server.
" This most likely only works on Unix and Windows.
if has('unix')
  " We also need the job feature or the pkill command to make sure the server
  " can be stopped.
  if !(executable('python') && (has('job') || executable('pkill')))
    finish
  endif
elseif has('win32')
  " Use Python Launcher for Windows (py.exe).
  if !executable('py')
    finish
  endif
else
  finish
endif

let s:port = -1

func s:start_server()
  " The Python program writes the port number in Xportnr.
  call delete("Xportnr")

  if has('job')
    let s:job = job_start("python test_channel.py")
  elseif has('win32')
    silent !start cmd /c start "test_channel" py test_channel.py
  else
    silent !python test_channel.py&
  endif

  " Wait for up to 2 seconds for the port number to be there.
  let cnt = 20
  let l = []
  while cnt > 0
    try
      let l = readfile("Xportnr")
    catch
    endtry
    if len(l) >= 1
      break
    endif
    sleep 100m
    let cnt -= 1
  endwhile
  call delete("Xportnr")

  if len(l) == 0
    " Can't make the connection, give up.
    call s:kill_server()
    call assert_false(1, "Can't start test_channel.py")
    return -1
  endif
  let s:port = l[0]

  let handle = ch_open('localhost:' . s:port)
  return handle
endfunc

func s:kill_server()
  if has('job')
    call job_stop(s:job)
  elseif has('win32')
    call system('taskkill /IM py.exe /T /F /FI "WINDOWTITLE eq test_channel"')
  else
    call system("pkill -f test_channel.py")
  endif
endfunc

let s:responseHandle = -1
let s:responseMsg = ''
func s:RequestHandler(handle, msg)
  let s:responseHandle = a:handle
  let s:responseMsg = a:msg
endfunc

func Test_communicate()
  let handle = s:start_server()
  if handle < 0
    return
  endif

  " Simple string request and reply.
  call assert_equal('got it', ch_sendexpr(handle, 'hello!'))

  " Request that triggers sending two ex commands.  These will usually be
  " handled before getting the response, but it's not guaranteed, thus wait a
  " tiny bit for the commands to get executed.
  call assert_equal('ok', ch_sendexpr(handle, 'make change'))
  sleep 10m
  call assert_equal('added1', getline(line('$') - 1))
  call assert_equal('added2', getline('$'))

  call assert_equal('ok', ch_sendexpr(handle, 'do normal'))
  sleep 10m
  call assert_equal('added more', getline('$'))

  " Send a request with a specific handler.
  call ch_sendexpr(handle, 'hello!', 's:RequestHandler')
  sleep 10m
  call assert_equal(handle, s:responseHandle)
  call assert_equal('got it', s:responseMsg)

  " Send an eval request that works.
  call assert_equal('ok', ch_sendexpr(handle, 'eval-works'))
  sleep 10m
  call assert_equal([-1, 'foo123'], ch_sendexpr(handle, 'eval-result'))

  " Send an eval request that fails.
  call assert_equal('ok', ch_sendexpr(handle, 'eval-fails'))
  sleep 10m
  call assert_equal([-2, 'ERROR'], ch_sendexpr(handle, 'eval-result'))

  " Send an eval request that works but can't be encoded.
  call assert_equal('ok', ch_sendexpr(handle, 'eval-error'))
  sleep 10m
  call assert_equal([-3, 'ERROR'], ch_sendexpr(handle, 'eval-result'))

  " Send a bad eval request. There will be no response.
  call assert_equal('ok', ch_sendexpr(handle, 'eval-bad'))
  sleep 10m
  call assert_equal([-3, 'ERROR'], ch_sendexpr(handle, 'eval-result'))

  " Send an expr request
  call assert_equal('ok', ch_sendexpr(handle, 'an expr'))
  sleep 10m
  call assert_equal('one', getline(line('$') - 2))
  call assert_equal('two', getline(line('$') - 1))
  call assert_equal('three', getline('$'))

  " Request a redraw, we don't check for the effect.
  call assert_equal('ok', ch_sendexpr(handle, 'redraw'))
  call assert_equal('ok', ch_sendexpr(handle, 'redraw!'))

  call assert_equal('ok', ch_sendexpr(handle, 'empty-request'))

  " make the server quit, can't check if this works, should not hang.
  call ch_sendexpr(handle, '!quit!', 0)

  call s:kill_server()
endfunc

" Test that we can open two channels.
func Test_two_channels()
  let handle = s:start_server()
  if handle < 0
    return
  endif
  call assert_equal('got it', ch_sendexpr(handle, 'hello!'))

  let newhandle = ch_open('localhost:' . s:port)
  call assert_equal('got it', ch_sendexpr(newhandle, 'hello!'))
  call assert_equal('got it', ch_sendexpr(handle, 'hello!'))

  call ch_close(handle)
  call assert_equal('got it', ch_sendexpr(newhandle, 'hello!'))

  call s:kill_server()
endfunc

" Test that a server crash is handled gracefully.
func Test_server_crash()
  let handle = s:start_server()
  if handle < 0
    return
  endif
  call ch_sendexpr(handle, '!crash!')

  " kill the server in case if failed to crash
  sleep 10m
  call s:kill_server()
endfunc

" Test that trying to connect to a non-existing port fails quickly.
func Test_connect_waittime()
  let start = reltime()
  let handle = ch_open('localhost:9876')
  if handle >= 0
    " Oops, port does exists.
    call ch_close(handle)
  else
    let elapsed = reltime(start)
    call assert_true(reltimefloat(elapsed) < 1.0)
  endif

  let start = reltime()
  let handle = ch_open('localhost:9867', {'waittime': 2000})
  if handle >= 0
    " Oops, port does exists.
    call ch_close(handle)
  else
    " Failed connection doesn't wait the full time on Unix.
    let elapsed = reltime(start)
    call assert_true(reltimefloat(elapsed) < (has('unix') ? 1.0 : 3.0))
  endif
endfunc
