package main

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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

func removeDirectivesFromWorkspace(workspaceFile string) error {
	workspace, err := os.OpenFile(workspaceFile, os.O_RDWR, 0644)
	if err != nil {
		return err
	}
	defer workspace.Close()

	workspaceWithoutDirectives, err := getWorkspaceWithoutDirectives(workspace)
	if err != nil {
		return err
	}

	// reuse the open workspace file, so first we empty it and rewind
	err = workspace.Truncate(0)
	if err != nil {
		return err
	}
	_ /* new offset */, err = workspace.Seek(0, io.SeekStart)
	if err != nil {
		return err
	}

	// write the directive-less workspace and update repos
	if _, err := workspace.Write(workspaceWithoutDirectives); err != nil {
		return err
	}

	return nil
}

func getWorkspaceWithoutDirectives(workspace io.Reader) ([]byte, error) {
	workspaceScanner := bufio.NewScanner(workspace)
	var workspaceWithoutDirectives bytes.Buffer
	for workspaceScanner.Scan() {
		currentLine := workspaceScanner.Text()
		if strings.HasPrefix(currentLine, "# gazelle:repository go_repository") {
			continue
		}
		if strings.HasPrefix(currentLine, "# gazelle:repository_macro ") {
			continue
		}
		_, err := workspaceWithoutDirectives.WriteString(currentLine + "\n")
		if err != nil {
			return nil, err
		}
	}
	// leave some buffering at the end of the bytes
	_, err := workspaceWithoutDirectives.WriteString("\n\n")
	if err != nil {
		return nil, err
	}
	return workspaceWithoutDirectives.Bytes(), workspaceScanner.Err()
}
