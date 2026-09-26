package tasks

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type stubStore struct {
	created Input
	updated Input
}

func (s *stubStore) List(context.Context) ([]Task, error) { return []Task{}, nil }
func (s *stubStore) Create(_ context.Context, in Input) (Task, error) {
	s.created = in
	return Task{ID: 1, Title: in.Title}, nil
}
func (s *stubStore) Update(_ context.Context, id int64, in Input) (Task, error) {
	s.updated = in
	return Task{ID: id, Title: in.Title, Description: in.Description, Completed: in.Completed}, nil
}
func (s *stubStore) Delete(context.Context, int64) error { return ErrNotFound }

func TestCreateTask(t *testing.T) {
	store := &stubStore{}
	mux := http.NewServeMux()
	NewHandler(store, slog.New(slog.NewTextHandler(io.Discard, nil))).Register(mux)
	req := httptest.NewRequest(http.MethodPost, "/api/tasks", strings.NewReader(`{"title":"  Learn Go  "}`))
	res := httptest.NewRecorder()
	mux.ServeHTTP(res, req)
	if res.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", res.Code, res.Body.String())
	}
	if store.created.Title != "Learn Go" {
		t.Fatalf("title = %q", store.created.Title)
	}
}

func TestCreateTaskValidation(t *testing.T) {
	mux := http.NewServeMux()
	NewHandler(&stubStore{}, slog.New(slog.NewTextHandler(io.Discard, nil))).Register(mux)
	req := httptest.NewRequest(http.MethodPost, "/api/tasks", strings.NewReader(`{"title":" "}`))
	res := httptest.NewRecorder()
	mux.ServeHTTP(res, req)
	if res.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, body = %s", res.Code, res.Body.String())
	}
}

func TestUpdateIgnoresReadOnlyResponseFields(t *testing.T) {
	store := &stubStore{}
	mux := http.NewServeMux()
	NewHandler(store, slog.New(slog.NewTextHandler(io.Discard, nil))).Register(mux)
	body := `{"id":3,"title":"Task","description":"Done","completed":true,"createdAt":"2026-09-26T12:31:57Z","updatedAt":"2026-09-26T12:31:57Z"}`
	req := httptest.NewRequest(http.MethodPut, "/api/tasks/3", strings.NewReader(body))
	res := httptest.NewRecorder()
	mux.ServeHTTP(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", res.Code, res.Body.String())
	}
	if !store.updated.Completed || store.updated.Title != "Task" {
		t.Fatalf("unexpected update: %+v", store.updated)
	}
}
