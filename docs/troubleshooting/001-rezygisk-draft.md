# ReZygisk Implementation Incomplete

- **ID**: TR-001
- **Status**: Investigating
- **Linked Issue**: N/A

## Description
The `stuff/reZygisk.py` file contains a draft implementation with several "TODO" or "Mock" sections.
Specifically:
- It doesn't actually extract the zip file.
- The `copy` method has mock copy logic.
- MD5 check is disabled/static.

## Attempted
- [x] Initial code review of `stuff/reZygisk.py`.

## Solution/Findings
Needs implementation of `zipfile` extraction and actual file mapping.

## Next Steps
- [ ] Implement `zipfile` extraction in `download` or `copy` method.
- [ ] Update `copy` method to move files from extracted temp dir to `copy_dir`.
