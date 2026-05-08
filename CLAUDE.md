# Rules

1. Do not add verbose comments.
   - You may write simple summarized docstrings.
2. Do not create large .swift files.
   - Separate large classes/enums/structs using extensions, grouped into its own folder.
   - Avoid view builders if they are long. Separate the views and create their own .swift files.
3. Do not use single or double letter variable names. Spell all variable names out in full (time instead of t, xPosition instead of x).
4. After you're done, always localize for every langauge possible.
   - Generate the object for each string in a separate file, then use Python to set the object as the value for localization keys in the xcstrings file.
   - Do not make large edits.
   - Do not generate localization strings as part of Python scripts.
   - Remember to clean up these working files after you're done.
5. Ensure that you properly mark out MainActor or nonisolated functions to comply with Swift 6 concurrency checking.

# Copywriting

- Always use 'Web Feeds' when referring to the Petal feature
- Always use the term 'content' and never 'article', 'article' is used internally only
