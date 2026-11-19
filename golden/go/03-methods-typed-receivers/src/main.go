package main

type Repo struct{}

func (r *Repo) Save(id int) error { return nil }

type Service struct {
	repo *Repo
}

func (s *Service) validate(id int) bool { return id > 0 }

func (s *Service) Create(id int) {
	if s.validate(id) {
		s.repo.Save(id)
	}
}

func audit(r *Repo) {
	r.Save(0)
}

func main() {
	var s Service
	s.Create(1)
	var r Repo
	audit(&r)
	r.Save(2)
}
