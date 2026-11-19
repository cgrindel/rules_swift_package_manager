package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestPortableFingerprints(t *testing.T) {
	var previous map[string]string
	for i := 0; i < 2; i++ {
		root := t.TempDir()
		if err := os.WriteFile(filepath.Join(root, "input"), []byte("SDK contents"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink("input", filepath.Join(root, "alias")); err != nil {
			t.Fatal(err)
		}
		got := map[string]string{}
		if err := fingerprintTree("sdk/MacOSX", root, got, map[string]bool{}); err != nil {
			t.Fatal(err)
		}
		if i > 0 && !reflect.DeepEqual(previous, got) {
			t.Fatalf("relocating inputs changed fingerprints: %v != %v", previous, got)
		}
		previous = got
	}
}

func TestFingerprintChangesAndCycles(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "input")
	os.WriteFile(path, []byte("old"), 0600)
	before, err := fingerprint(path)
	if err != nil {
		t.Fatal(err)
	}
	os.WriteFile(path, []byte("new"), 0600)
	after, err := fingerprint(path)
	if err != nil {
		t.Fatal(err)
	}
	if before == after {
		t.Fatal("content change did not change fingerprint")
	}
	os.Symlink(".", filepath.Join(root, "cycle"))
	if err := fingerprintTree("sdk", root, map[string]string{}, map[string]bool{}); err == nil {
		t.Fatal("accepted a directory cycle")
	}
}

func TestXcodeVersion(t *testing.T) {
	got, err := xcodeVersion("Xcode 27.0\nBuild version 27A266a\n")
	if err != nil || got != "27.0.0.27A266a" {
		t.Fatalf("got %q, %v", got, err)
	}
	if _, err := xcodeVersion("Xcode 27.0"); err == nil {
		t.Fatal("accepted missing build stamp")
	}
}

func TestProfiles(t *testing.T) {
	for _, triple := range []string{"arm64-apple-ios15.0-simulator", "x86_64-apple-ios16.0-simulator"} {
		if err := validateProfile("iPhoneSimulator", triple); err != nil {
			t.Fatal(err)
		}
	}
	for _, triple := range []string{"arm64-apple-ios15.0", "arm64e-apple-ios15.0-simulator", "arm64-apple-ios-simulator"} {
		if err := validateProfile("iPhoneSimulator", triple); err == nil {
			t.Fatalf("accepted %s", triple)
		}
	}
}

func TestGraphModules(t *testing.T) {
	got, err := graphModules([]byte(`{"modules":[{"swift":"RSPMSDKInventory"},{},{"swift":"Foundation"},{},{"clang":"Foundation"},{},{"clang":"Dispatch"},{}]}`))
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, []string{"Dispatch", "Foundation"}) {
		t.Fatalf("got %v", got)
	}
	for _, bad := range []string{`{}`, `{"modules":[{},{},{}]}`, `{"modules":[{},{},{"unknown":"X"},{}]}`} {
		if _, err := graphModules([]byte(bad)); err == nil {
			t.Fatalf("accepted %s", bad)
		}
	}
}

func TestStrictJSON(t *testing.T) {
	path := filepath.Join(t.TempDir(), "request.json")
	for _, contents := range []string{`{"target":{}}`, `{} {}`} {
		os.WriteFile(path, []byte(contents), 0600)
		var request Request
		if err := readJSON(path, &request); err == nil {
			t.Fatalf("accepted %s", contents)
		}
	}
}
