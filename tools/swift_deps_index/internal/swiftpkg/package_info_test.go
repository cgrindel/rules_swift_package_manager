package swiftpkg_test

import (
	"os"
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftbin"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
	"github.com/stretchr/testify/assert"
)

func TestPackageInfo(t *testing.T) {
	t.Run("create", func(t *testing.T) {
		// Create temp dir
		dir, err := os.MkdirTemp("", "swiftpkg")
		assert.NoError(t, err)
		defer os.RemoveAll(dir)

		// Create a build directory
		buildDir, err := os.MkdirTemp("", "builddir")
		assert.NoError(t, err)
		defer os.RemoveAll(buildDir)

		// Find Swift
		binPath, err := swiftbin.FindSwiftBinPath()
		assert.NoError(t, err)
		sb := swiftbin.NewSwiftBin(binPath)

		// Init a package
		pkgName := "MyPackage"
		err = sb.InitPackage(dir, pkgName, "library")
		assert.NoError(t, err)

		pi, err := swiftpkg.NewPackageInfo(sb, dir, buildDir)
		assert.NoError(t, err)
		assert.Equal(t, pkgName, pi.Name)
	})

	t.Run("new from JSON", func(t *testing.T) {
		pi, err := swiftpkg.NewPackageInfoFromJSON([]byte(packageInfoJSONStr))
		assert.NoError(t, err)
		assert.NotNil(t, pi)
		assert.Equal(t, "swift-composable-architecture", pi.Name)
		assert.Len(t, pi.Dependencies, 14)
		assert.Len(t, pi.Platforms, 4)
		assert.Len(t, pi.Products, 1)
		assert.Len(t, pi.Targets, 5)
	})
}

func TestManifestProductReferences(t *testing.T) {
	m := swiftpkg.PackageInfo{
		Targets: []*swiftpkg.Target{
			&swiftpkg.Target{
				Dependencies: []*swiftpkg.TargetDependency{
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Foo", Identity: "repoA"}},
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Bar", Identity: "repoA"}},
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Chicken", Identity: "repoB"}},
				},
			},
			&swiftpkg.Target{
				Dependencies: []*swiftpkg.TargetDependency{
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Foo", Identity: "repoA"}},
					&swiftpkg.TargetDependency{Product: &swiftpkg.ProductReference{ProductName: "Smidgen", Identity: "repoB"}},
				},
			},
		},
	}

	actual := m.ProductReferences()
	expected := []*swiftpkg.ProductReference{
		&swiftpkg.ProductReference{ProductName: "Bar", Identity: "repoA"},
		&swiftpkg.ProductReference{ProductName: "Foo", Identity: "repoA"},
		&swiftpkg.ProductReference{ProductName: "Chicken", Identity: "repoB"},
		&swiftpkg.ProductReference{ProductName: "Smidgen", Identity: "repoB"},
	}
	assert.Equal(t, expected, actual)
}

const packageInfoJSONStr = `
{
  "default_localization": "en",
  "dependencies": [
    {
      "file_system": null,
      "identity": "swift-collections",
      "name": "swift-collections",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-docc-plugin",
      "name": "swift-docc-plugin",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-syntax",
      "name": "swift-syntax",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-benchmark",
      "name": "swift-benchmark",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "combine-schedulers",
      "name": "combine-schedulers",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-case-paths",
      "name": "swift-case-paths",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-concurrency-extras",
      "name": "swift-concurrency-extras",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-custom-dump",
      "name": "swift-custom-dump",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-dependencies",
      "name": "swift-dependencies",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-identified-collections",
      "name": "swift-identified-collections",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-macro-testing",
      "name": "swift-macro-testing",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swift-perception",
      "name": "swift-perception",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "swiftui-navigation",
      "name": "swiftui-navigation",
      "source_control": {
        "pin": null
      }
    },
    {
      "file_system": null,
      "identity": "xctest-dynamic-overlay",
      "name": "xctest-dynamic-overlay",
      "source_control": {
        "pin": null
      }
    }
  ],
  "name": "swift-composable-architecture",
  "path": "/private/var/tmp/_bazel_chuck/160d4d71af423ac712350c0996bc3c43/external/rules_swift_package_manager~~swift_deps~swiftpkg_swift_composable_architecture",
  "platforms": [
    {
      "name": "ios",
      "version": "13.0"
    },
    {
      "name": "macos",
      "version": "10.15"
    },
    {
      "name": "tvos",
      "version": "13.0"
    },
    {
      "name": "watchos",
      "version": "6.0"
    }
  ],
  "products": [
    {
      "name": "ComposableArchitecture",
      "targets": [
        "ComposableArchitecture"
      ],
      "type": {
        "executable": false,
        "is_executable": false,
        "is_library": true,
        "is_macro": false,
        "is_plugin": false,
        "library": {
          "kind": "automatic"
        }
      }
    }
  ],
  "targets": [
    {
      "artifact_download_info": null,
      "c99name": "ComposableArchitecture",
      "clang_settings": null,
      "clang_src_info": null,
      "cxx_settings": null,
      "dependencies": [
        {
          "by_name": {
            "condition": null,
            "name": "ComposableArchitectureMacros"
          },
          "product": null,
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-case-paths",
            "product_name": "CasePaths"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "combine-schedulers",
            "product_name": "CombineSchedulers"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-concurrency-extras",
            "product_name": "ConcurrencyExtras"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-custom-dump",
            "product_name": "CustomDump"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-dependencies",
            "product_name": "Dependencies"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-dependencies",
            "product_name": "DependenciesMacros"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-identified-collections",
            "product_name": "IdentifiedCollections"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-collections",
            "product_name": "OrderedCollections"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-perception",
            "product_name": "Perception"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swiftui-navigation",
            "product_name": "SwiftUINavigationCore"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "xctest-dynamic-overlay",
            "product_name": "XCTestDynamicOverlay"
          },
          "target": null
        }
      ],
      "exclude_paths": [],
      "label": {
        "name": "ComposableArchitecture.rspm",
        "package": "",
        "repository_name": "@"
      },
      "linker_settings": null,
      "module_type": "SwiftTarget",
      "name": "ComposableArchitecture",
      "objc_src_info": null,
      "path": "Sources/ComposableArchitecture",
      "product_memberships": [],
      "public_hdrs_path": null,
      "resources": [],
      "source_paths": null,
      "sources": [
        "CaseReducer.swift",
        "Dependencies/Dismiss.swift",
        "Dependencies/IsPresented.swift",
        "Effect.swift",
        "Effects/Animation.swift",
        "Effects/Cancellation.swift",
        "Effects/Debounce.swift",
        "Effects/EffectActions.swift",
        "Effects/Publisher.swift",
        "Effects/TaskResult.swift",
        "Effects/Throttle.swift",
        "Internal/AreOrderedSetsDuplicates.swift",
        "Internal/Binding+IsPresent.swift",
        "Internal/Box.swift",
        "Internal/Create.swift",
        "Internal/CurrentValueRelay.swift",
        "Internal/Debug.swift",
        "Internal/Deprecations.swift",
        "Internal/EphemeralState.swift",
        "Internal/Exports.swift",
        "Internal/Locking.swift",
        "Internal/Logger.swift",
        "Internal/NavigationID.swift",
        "Internal/OpenExistential.swift",
        "Internal/PresentationID.swift",
        "Internal/ReturningLastNonNilValue.swift",
        "Internal/RuntimeWarnings.swift",
        "Internal/StackIDGenerator.swift",
        "Internal/TypeName.swift",
        "Macros.swift",
        "Observation/Alert+Observation.swift",
        "Observation/Binding+Observation.swift",
        "Observation/IdentifiedArray+Observation.swift",
        "Observation/NavigationStack+Observation.swift",
        "Observation/ObservableState.swift",
        "Observation/ObservationStateRegistrar.swift",
        "Observation/Store+Observation.swift",
        "Observation/ViewAction.swift",
        "Reducer.swift",
        "Reducer/ReducerBuilder.swift",
        "Reducer/Reducers/BindingReducer.swift",
        "Reducer/Reducers/CombineReducers.swift",
        "Reducer/Reducers/DebugReducer.swift",
        "Reducer/Reducers/DependencyKeyWritingReducer.swift",
        "Reducer/Reducers/EmptyReducer.swift",
        "Reducer/Reducers/ForEachReducer.swift",
        "Reducer/Reducers/IfCaseLetReducer.swift",
        "Reducer/Reducers/IfLetReducer.swift",
        "Reducer/Reducers/OnChange.swift",
        "Reducer/Reducers/Optional.swift",
        "Reducer/Reducers/PresentationReducer.swift",
        "Reducer/Reducers/Reduce.swift",
        "Reducer/Reducers/Scope.swift",
        "Reducer/Reducers/SignpostReducer.swift",
        "Reducer/Reducers/StackReducer.swift",
        "RootStore.swift",
        "Store.swift",
        "SwiftUI/Alert.swift",
        "SwiftUI/Binding.swift",
        "SwiftUI/ConfirmationDialog.swift",
        "SwiftUI/Deprecated/ActionSheet.swift",
        "SwiftUI/Deprecated/LegacyAlert.swift",
        "SwiftUI/Deprecated/NavigationLinkStore.swift",
        "SwiftUI/ForEachStore.swift",
        "SwiftUI/FullScreenCover.swift",
        "SwiftUI/IfLetStore.swift",
        "SwiftUI/NavigationDestination.swift",
        "SwiftUI/NavigationStackStore.swift",
        "SwiftUI/Popover.swift",
        "SwiftUI/PresentationModifier.swift",
        "SwiftUI/Sheet.swift",
        "SwiftUI/SwitchStore.swift",
        "SwiftUI/WithViewStore.swift",
        "TestStore.swift",
        "UIKit/AlertStateUIKit.swift",
        "UIKit/IfLetUIKit.swift",
        "UIKit/NSObject+Observation.swift",
        "ViewStore.swift"
      ],
      "swift_settings": null,
      "swift_src_info": {
        "discovered_res_files": [],
        "has_objc_directive": true
      },
      "type": "regular"
    },
    {
      "artifact_download_info": null,
      "c99name": "ComposableArchitectureTests",
      "clang_settings": null,
      "clang_src_info": null,
      "cxx_settings": null,
      "dependencies": [
        {
          "by_name": {
            "condition": null,
            "name": "ComposableArchitecture"
          },
          "product": null,
          "target": null
        }
      ],
      "exclude_paths": [],
      "label": {
        "name": "ComposableArchitectureTests.rspm",
        "package": "",
        "repository_name": "@"
      },
      "linker_settings": null,
      "module_type": "SwiftTarget",
      "name": "ComposableArchitectureTests",
      "objc_src_info": null,
      "path": "Tests/ComposableArchitectureTests",
      "product_memberships": [],
      "public_hdrs_path": null,
      "resources": [],
      "source_paths": null,
      "sources": [
        "BindableStoreTests.swift",
        "BindingLocalTests.swift",
        "CompatibilityTests.swift",
        "ComposableArchitectureTests.swift",
        "DebugTests.swift",
        "DependencyKeyWritingReducerTests.swift",
        "EffectCancellationTests.swift",
        "EffectDebounceTests.swift",
        "EffectFailureTests.swift",
        "EffectOperationTests.swift",
        "EffectRunTests.swift",
        "EffectTests.swift",
        "EnumReducerMacroTests.swift",
        "Internal/BaseTCATestCase.swift",
        "Internal/TestHelpers.swift",
        "MacroTests.swift",
        "MemoryManagementTests.swift",
        "ObservableStateEnumMacroTests.swift",
        "ObservableTests.swift",
        "ObserveTests.swift",
        "ReducerBuilderTests.swift",
        "ReducerTests.swift",
        "Reducers/BindingReducerTests.swift",
        "Reducers/ForEachReducerTests.swift",
        "Reducers/IfCaseLetReducerTests.swift",
        "Reducers/IfLetReducerTests.swift",
        "Reducers/OnChangeReducerTests.swift",
        "Reducers/PresentationReducerTests.swift",
        "Reducers/StackReducerTests.swift",
        "RuntimeWarningTests.swift",
        "ScopeCacheTests.swift",
        "ScopeLoggerTests.swift",
        "ScopeTests.swift",
        "StoreFilterTests.swift",
        "StoreLifetimeTests.swift",
        "StorePerceptionTests.swift",
        "StoreTests.swift",
        "TaskCancellationTests.swift",
        "TaskResultTests.swift",
        "TestStoreFailureTests.swift",
        "TestStoreNonExhaustiveTests.swift",
        "TestStoreTests.swift",
        "ThrottleTests.swift",
        "ViewStoreTests.swift"
      ],
      "swift_settings": null,
      "swift_src_info": {
        "discovered_res_files": [],
        "has_objc_directive": false
      },
      "type": "test"
    },
    {
      "artifact_download_info": null,
      "c99name": "ComposableArchitectureMacros",
      "clang_settings": null,
      "clang_src_info": null,
      "cxx_settings": null,
      "dependencies": [
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-syntax",
            "product_name": "SwiftSyntaxMacros"
          },
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-syntax",
            "product_name": "SwiftCompilerPlugin"
          },
          "target": null
        }
      ],
      "exclude_paths": [],
      "label": {
        "name": "ComposableArchitectureMacros.rspm",
        "package": "",
        "repository_name": "@"
      },
      "linker_settings": null,
      "module_type": "SwiftTarget",
      "name": "ComposableArchitectureMacros",
      "objc_src_info": null,
      "path": "Sources/ComposableArchitectureMacros",
      "product_memberships": [],
      "public_hdrs_path": null,
      "resources": [],
      "source_paths": null,
      "sources": [
        "Availability.swift",
        "Extensions.swift",
        "ObservableStateMacro.swift",
        "Plugins.swift",
        "PresentsMacro.swift",
        "ReducerMacro.swift",
        "ViewActionMacro.swift"
      ],
      "swift_settings": null,
      "swift_src_info": {
        "discovered_res_files": [],
        "has_objc_directive": false
      },
      "type": "macro"
    },
    {
      "artifact_download_info": null,
      "c99name": "ComposableArchitectureMacrosTests",
      "clang_settings": null,
      "clang_src_info": null,
      "cxx_settings": null,
      "dependencies": [
        {
          "by_name": {
            "condition": null,
            "name": "ComposableArchitectureMacros"
          },
          "product": null,
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-macro-testing",
            "product_name": "MacroTesting"
          },
          "target": null
        }
      ],
      "exclude_paths": [],
      "label": {
        "name": "ComposableArchitectureMacrosTests.rspm",
        "package": "",
        "repository_name": "@"
      },
      "linker_settings": null,
      "module_type": "SwiftTarget",
      "name": "ComposableArchitectureMacrosTests",
      "objc_src_info": null,
      "path": "Tests/ComposableArchitectureMacrosTests",
      "product_memberships": [],
      "public_hdrs_path": null,
      "resources": [],
      "source_paths": null,
      "sources": [
        "MacroBaseTestCase.swift",
        "ObservableStateMacroTests.swift",
        "PresentsMacroTests.swift",
        "ReducerMacroTests.swift",
        "ViewActionMacroTests.swift"
      ],
      "swift_settings": null,
      "swift_src_info": {
        "discovered_res_files": [],
        "has_objc_directive": false
      },
      "type": "test"
    },
    {
      "artifact_download_info": null,
      "c99name": "swift_composable_architecture_benchmark",
      "clang_settings": null,
      "clang_src_info": null,
      "cxx_settings": null,
      "dependencies": [
        {
          "by_name": {
            "condition": null,
            "name": "ComposableArchitecture"
          },
          "product": null,
          "target": null
        },
        {
          "by_name": null,
          "product": {
            "condition": null,
            "dep_name": "swift-benchmark",
            "product_name": "Benchmark"
          },
          "target": null
        }
      ],
      "exclude_paths": [],
      "label": {
        "name": "swift-composable-architecture-benchmark.rspm",
        "package": "",
        "repository_name": "@"
      },
      "linker_settings": null,
      "module_type": "SwiftTarget",
      "name": "swift-composable-architecture-benchmark",
      "objc_src_info": null,
      "path": "Sources/swift-composable-architecture-benchmark",
      "product_memberships": [],
      "public_hdrs_path": null,
      "resources": [],
      "source_paths": null,
      "sources": [
        "Common.swift",
        "Dependencies.swift",
        "Effects.swift",
        "Observation.swift",
        "StoreScope.swift",
        "StoreSuite.swift",
        "ViewStore.swift",
        "main.swift"
      ],
      "swift_settings": null,
      "swift_src_info": {
        "discovered_res_files": [],
        "has_objc_directive": false
      },
      "type": "executable"
    }
  ],
  "tools_version": "5.9.0"
}
`
