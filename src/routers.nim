import jester, ws, ws/jester_extra
  
router directRouter:
  get "/hello":
    resp "<h1>Hello World!</h1>"


export directRouter