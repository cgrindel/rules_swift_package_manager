package main

import (
	"encoding/json"
	"reflect"
	"testing"
)

func rawDependency(text string) map[string][]json.RawMessage {
	var dep map[string][]json.RawMessage
	if err := json.Unmarshal([]byte(text), &dep); err != nil {
		panic(err)
	}
	return dep
}

func TestTransitiveModulesRetainPlatformConditions(t *testing.T) {
	consumer := &packageInfo{
		graph: graphPackage{Identity: "consumer", Dependencies: []graphPackage{{Identity: "helper"}}},
		targets: map[string]manifestTarget{
			"Consumer": {Name: "Consumer", Dependencies: []map[string][]json.RawMessage{rawDependency(`{"product":["Helpers","helper",null,{"platformNames":["ios"]}]}`)}},
		},
		descriptions: map[string]describedTarget{"Consumer": {C99name: "Consumer"}},
	}
	helper := &packageInfo{
		graph: graphPackage{Identity: "helper"},
		targets: map[string]manifestTarget{
			"Helper":         {Name: "Helper", Dependencies: []map[string][]json.RawMessage{rawDependency(`{"target":["Implementation",null]}`)}},
			"Implementation": {Name: "Implementation"},
			"Unused":         {Name: "Unused"},
		},
		descriptions: map[string]describedTarget{"Helper": {C99name: "HelperModule"}, "Implementation": {C99name: "Implementation"}, "Unused": {C99name: "UIKit"}},
	}
	if err := json.Unmarshal([]byte(`{"name":"HelperPackage","products":[{"name":"Helpers","targets":["Helper"]}]}`), &helper.manifest); err != nil {
		t.Fatal(err)
	}
	packages := map[string]*packageInfo{"consumer": consumer, "helper": helper}
	for platform, expected := range map[string][]string{"ios": {"Consumer", "HelperModule", "Implementation"}, "macos": {"Consumer"}} {
		got, err := dependencyModules(consumer, "Consumer", platform, packages)
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(got, expected) {
			t.Fatalf("%s modules = %v, want %v", platform, got, expected)
		}
	}
}

func TestPortableArguments(t *testing.T) {
	p := &packageInfo{
		aliases:      map[string]string{"Consumer": "RenamedConsumer"},
		aliasFlags:   map[string]string{"Testing": "PackageTesting"},
		traits:       map[string]bool{"Feature": true},
		descriptions: map[string]describedTarget{"Consumer": {C99name: "Consumer", Path: "Sources/Consumer", Sources: []string{"z.swift", "a.swift"}}},
	}
	if err := json.Unmarshal([]byte(`{"toolsVersion":{"_version":"5.7.0"}}`), &p.manifest); err != nil {
		t.Fatal(err)
	}
	var target manifestTarget
	if err := json.Unmarshal([]byte(`{"name":"Consumer","settings":[{"tool":"swift","kind":{"define":{"_0":"IOS"}},"condition":{"platformNames":["ios"]}},{"tool":"swift","kind":{"define":{"_0":"RELEASE"}},"condition":{"config":"release"}},{"tool":"swift","kind":{"enableUpcomingFeature":{"_0":"ExistentialAny"}}}]}`), &target); err != nil {
		t.Fatal(err)
	}
	got, err := scanArguments(p, target, Request{Targets: map[string]string{"iPhoneSimulator": "arm64-apple-ios15.0-simulator"}, Defines: []string{"CUSTOM"}}, "iPhoneSimulator", "ios", "debug", []string{"Testing"})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"-frontend", "-scan-dependencies", "-import-prescan", "-module-name", "RenamedConsumer",
		"-sdk", "${SDK}", "-target", "arm64-apple-ios15.0-simulator", "-module-cache-path", "${MODULE_CACHE}",
		"-DSWIFT_PACKAGE", "-Onone", "-DDEBUG", "-DCUSTOM", "-DFeature",
		"-module-can-import", "PackageTesting", "-module-can-import", "Testing",
		"-module-alias", "Testing=PackageTesting", "-swift-version", "5", "-DIOS",
		"-enable-upcoming-feature", "ExistentialAny", "Sources/Consumer/a.swift", "Sources/Consumer/z.swift",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("args = %#v\nwant = %#v", got, want)
	}
}

func TestUnsupportedFlagsFailBeforeCacheWrite(t *testing.T) {
	p := &packageInfo{descriptions: map[string]describedTarget{"Consumer": {C99name: "Consumer"}}}
	var target manifestTarget
	if err := json.Unmarshal([]byte(`{"name":"Consumer","settings":[{"tool":"swift","kind":{"unsafeFlags":{"_0":["-cxx-interoperability-mode=default"]}}}]}`), &target); err != nil {
		t.Fatal(err)
	}
	if _, err := scanArguments(p, target, Request{Targets: map[string]string{"MacOSX": "arm64-apple-macosx14.0"}}, "MacOSX", "macos", "debug", nil); err == nil {
		t.Fatal("accepted unsupported prescan options")
	}
}

func TestTraitsAndConfiguration(t *testing.T) {
	c := &condition{Traits: []string{"Optional"}, Platforms: []string{"ios"}, Configuration: "release"}
	for _, test := range []struct {
		platform, config string
		enabled, want    bool
	}{
		{"ios", "release", true, true}, {"macos", "release", true, false},
		{"ios", "debug", true, false}, {"ios", "release", false, false},
	} {
		if got := active(c, test.platform, test.config, map[string]bool{"Optional": test.enabled}); got != test.want {
			t.Fatalf("%+v: %v", test, got)
		}
	}
}

func TestDisabledTraitDoesNotRemoveDefaultLanguageMode(t *testing.T) {
	p := &packageInfo{descriptions: map[string]describedTarget{"Consumer": {C99name: "Consumer"}}}
	p.manifest.ToolsVersion.Version = "5.7.0"
	var target manifestTarget
	if err := json.Unmarshal([]byte(`{"name":"Consumer","settings":[{"tool":"swift","kind":{"swiftLanguageMode":{"_0":"6"}},"condition":{"traits":["Experimental"]}}]}`), &target); err != nil {
		t.Fatal(err)
	}
	args, err := scanArguments(p, target, Request{Targets: map[string]string{"MacOSX": "arm64-apple-macosx14.0"}}, "MacOSX", "macos", "debug", nil)
	if err != nil {
		t.Fatal(err)
	}
	for i, arg := range args {
		if arg == "-swift-version" && args[i+1] == "5" {
			return
		}
	}
	t.Fatalf("missing default Swift language mode: %v", args)
}
