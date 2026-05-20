package accounts

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// TestNoHandleRegistrationEndpoint verifies that the accounts package contains
// no handle/display-name registration API (§14.9 — no central handle registry).
//
// This is a negative structural test: it parses the accounts package source and
// asserts that no exported function accepts a parameter that looks like a handle,
// username, or display_name.
func TestNoHandleRegistrationEndpoint(t *testing.T) {
	// Locate the accounts package source directory.
	_, thisFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	pkgDir := filepath.Dir(thisFile)

	fset := token.NewFileSet()
	pkgs, err := parser.ParseDir(fset, pkgDir, func(fi os.FileInfo) bool {
		// Skip test files so we don't detect our own test parameter names.
		return !strings.HasSuffix(fi.Name(), "_test.go")
	}, 0)
	if err != nil {
		t.Fatalf("parse accounts package: %v", err)
	}

	// Words that would imply a handle / display-name parameter.
	forbidden := []string{
		"handle", "username", "display_name", "displayname", "nickname",
		"alias", "screen_name", "screenname",
	}

	for _, pkg := range pkgs {
		for fileName, file := range pkg.Files {
			for _, decl := range file.Decls {
				fn, ok := decl.(*ast.FuncDecl)
				if !ok || fn.Name == nil || !fn.Name.IsExported() {
					continue
				}
				if fn.Type == nil || fn.Type.Params == nil {
					continue
				}
				for _, field := range fn.Type.Params.List {
					for _, name := range field.Names {
						lower := strings.ToLower(name.Name)
						for _, word := range forbidden {
							if strings.Contains(lower, word) {
								t.Errorf(
									"%s: exported function %s() has a handle-like parameter %q — "+
										"the accounts package must not provide handle registration (§14.9)",
									filepath.Base(fileName), fn.Name.Name, name.Name,
								)
							}
						}
					}
				}
			}
		}
	}
}

// TestRegisterFunctionSignatureHasNoDisplayName verifies that the specific
// Register() function signature does not include a display-name parameter.
func TestRegisterFunctionSignatureHasNoDisplayName(t *testing.T) {
	r := NewRegistry()
	// Register takes exactly (accountPub, devicePub string).
	// This call must compile; if Register's signature ever gains a third
	// display-name parameter, this test will fail to compile.
	if err := r.Register("acct-pub", "device-pub"); err != nil {
		// ErrDeviceCapExceeded can be returned in some edge cases;
		// the important thing is the signature compiles with 2 args.
		t.Logf("Register returned (expected): %v", err)
	}
}
