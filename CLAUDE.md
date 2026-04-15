1. Do not add overly verbose comments (doc comments are fine).
2. Do not create large .swift files.
   - Separate large classes/enums/structs using extensions, grouped into its own folder.
   - Avoid view builders if they are long. Separate the views and create their own .swift files.
4. After you're done, always localize for every langauge possible.
   - Generate the object for each string in a separate file, then use Python to set the object as the value for localization keys in the xcstrings file.
   - Do not make large edits.
   - Do not generate localization strings as part of Python scripts.
