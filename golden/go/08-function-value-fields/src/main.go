package main

type Server struct {
	handler func(string) error
	hooks   []func()
}

func (s *Server) Serve(path string) error {
	for _, h := range s.hooks {
		h()
	}
	return s.handler(path)
}

func ping() {}

func main() {
	var s Server
	s.handler = func(p string) error { return nil }
	s.hooks = append(s.hooks, ping)
	_ = s.Serve("/")
}
