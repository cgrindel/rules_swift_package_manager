package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func findWorkspaceFile(repoRoot string) (string, error) {
	workspaceFile := filepath.Join(repoRoot, "WORKSPACE")
	if _, err := os.Stat(workspaceFile); errors.Is(err, os.ErrNotExist) {
		workspaceFile = filepath.Join(repoRoot, "WORKSPACE.bazel")
		if _, err := os.Stat(workspaceFile); err != nil {
			return "", fmt.Errorf("could not find the Bazel workspace file: %w", err)
		}
	} else if err != nil {
		return "", err
	}
	return workspaceFile, nil
}

func backUpWorkspaceFile(ctx context.Context, workspaceFile string) (string, error) {
	repoRoot := filepath.Dir(workspaceFile)
	backupFile := filepath.Join(repoRoot, filepath.Base(workspaceFile)+".bak")
	if err := copyFile(ctx, workspaceFile, backupFile); err != nil {
		return "", fmt.Errorf("failed to backup workspace file: %w", err)
	}
	return backupFile, nil
}

func restoreWorkspaceFile(ctx context.Context, workspaceFile, backupFile string) error {
	if err := copyFile(ctx, backupFile, workspaceFile); err != nil {
		return fmt.Errorf("failed to restore the workspace file: %w", err)
	}
	if err := os.Remove(backupFile); err != nil {
		return fmt.Errorf("failed to remove backup file: %w", err)
	}
	return nil
}

func copyFile(ctx context.Context, src, dst string) error {
	cmd := exec.CommandContext(ctx, "cp", src, dst)
	if out, err := cmd.CombinedOutput(); err != nil {
		fmt.Println(string(out))
		return fmt.Errorf("failed to copy %s to %s: %w", src, dst, err)
	}
	return nil
}
