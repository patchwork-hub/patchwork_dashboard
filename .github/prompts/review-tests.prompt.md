---
mode: ask
model: GPT-5.3-Codex
description: Check whether the tests really prove the change is correct.
---
Review the tests for this change.

Review only the test files and the code under test that I attached.
Do not read the whole repo.

Check:
1. Do the tests actually prove the intended behavior, or just that the code
   runs? A passing test is not proof it tests the right thing.
2. Do they test the buggy or wrong behavior by mistake (asserting what the
   code does, not what it should do)?
3. Missing cases: edge cases, error paths, and boundaries with no test.
4. Are the tests clear and independent, or do they depend on each other?

Do not rewrite the tests. Point out what is missing or wrong.

Output:
- List each gap on one line, marked high, medium, or low.
- End with one line: TESTS ADEQUATE or TESTS NEED WORK.
- If the tests are solid, say so and stop.
