package tasks

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("task not found")

type Task struct {
	ID          int64     `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Completed   bool      `json:"completed"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

type Input struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Completed   bool   `json:"completed"`
}

func (in *Input) Validate() error {
	in.Title = strings.TrimSpace(in.Title)
	in.Description = strings.TrimSpace(in.Description)
	if in.Title == "" {
		return errors.New("title is required")
	}
	if len([]rune(in.Title)) > 200 {
		return errors.New("title must be at most 200 characters")
	}
	return nil
}

type Store interface {
	List(context.Context) ([]Task, error)
	Create(context.Context, Input) (Task, error)
	Update(context.Context, int64, Input) (Task, error)
	Delete(context.Context, int64) error
}

type PostgresStore struct{ pool *pgxpool.Pool }

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore { return &PostgresStore{pool: pool} }

const columns = "id, title, description, completed, created_at, updated_at"

func scanTask(row pgx.Row) (Task, error) {
	var task Task
	err := row.Scan(&task.ID, &task.Title, &task.Description, &task.Completed, &task.CreatedAt, &task.UpdatedAt)
	return task, err
}

func (s *PostgresStore) List(ctx context.Context) ([]Task, error) {
	rows, err := s.pool.Query(ctx, "SELECT "+columns+" FROM tasks ORDER BY created_at DESC, id DESC")
	if err != nil {
		return nil, fmt.Errorf("list tasks: %w", err)
	}
	defer rows.Close()
	tasks := make([]Task, 0)
	for rows.Next() {
		task, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("scan task: %w", err)
		}
		tasks = append(tasks, task)
	}
	return tasks, rows.Err()
}

func (s *PostgresStore) Create(ctx context.Context, in Input) (Task, error) {
	query := "INSERT INTO tasks(title, description, completed) VALUES($1,$2,$3) RETURNING " + columns
	task, err := scanTask(s.pool.QueryRow(ctx, query, in.Title, in.Description, in.Completed))
	if err != nil {
		return Task{}, fmt.Errorf("create task: %w", err)
	}
	return task, nil
}

func (s *PostgresStore) Update(ctx context.Context, id int64, in Input) (Task, error) {
	query := "UPDATE tasks SET title=$1, description=$2, completed=$3, updated_at=now() WHERE id=$4 RETURNING " + columns
	task, err := scanTask(s.pool.QueryRow(ctx, query, in.Title, in.Description, in.Completed, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return Task{}, ErrNotFound
	}
	if err != nil {
		return Task{}, fmt.Errorf("update task: %w", err)
	}
	return task, nil
}

func (s *PostgresStore) Delete(ctx context.Context, id int64) error {
	result, err := s.pool.Exec(ctx, "DELETE FROM tasks WHERE id=$1", id)
	if err != nil {
		return fmt.Errorf("delete task: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
