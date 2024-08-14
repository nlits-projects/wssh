import jester, ws, ws/jester_extra
  
router wsshRouter:
  get "/hello":
    resp "<h1>Hello World!</h1>"


export wsshRouter