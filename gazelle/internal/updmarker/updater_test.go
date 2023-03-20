package updmarker_test

import (
	"testing"

	"github.com/cgrindel/swift_bazel/gazelle/internal/updmarker"
	"github.com/stretchr/testify/assert"
)

func TestUpdater(t *testing.T) {
	startMarker := "# foo_bar START\n"
	endMarker := "# foo_bar END\n"
	updater := updmarker.NewUpdater(startMarker, endMarker)

	t.Run("update string", func(t *testing.T) {
		snippet := `Snippet First line
🙂
Snippet Second line
`
		tests := []struct {
			msg string
			in  string
			exp string
		}{
			{
				msg: "no markers in the input",
				in: `
Content First Line
Content Second Line
`,
				exp: `
Content First Line
Content Second Line
# foo_bar START
Snippet First line
🙂
Snippet Second line
# foo_bar END
`,
			},
			{
				msg: "markers in the middle of the input",
				in: `
Content First Line
# foo_bar START
# foo_bar END
Content Second Line
`,
				exp: `
Content First Line
# foo_bar START
Snippet First line
🙂
Snippet Second line
# foo_bar END
Content Second Line
`,
			},
			{
				msg: "markers at beginning of the input",
				in: `# foo_bar START
# foo_bar END
Content First Line
Content Second Line
`,
				exp: `# foo_bar START
Snippet First line
🙂
Snippet Second line
# foo_bar END
Content First Line
Content Second Line
`,
			},
			{
				msg: "markers at end of the input",
				in: `
Content First Line
Content Second Line
# foo_bar START
# foo_bar END
`,
				exp: `
Content First Line
Content Second Line
# foo_bar START
Snippet First line
🙂
Snippet Second line
# foo_bar END
`,
			},
		}
		for _, tt := range tests {
			actual, err := updater.UpdateString(tt.in, snippet)
			assert.NoError(t, err, tt.msg)
			assert.Equal(t, tt.exp, actual, tt.msg)
		}
	})
}
