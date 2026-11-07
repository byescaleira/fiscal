#!/usr/bin/env python3
import contextlib
import importlib.util
import io
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.abspath(__file__))
SPEC = importlib.util.spec_from_file_location("portrait_check", os.path.join(ROOT, "portrait-check.py"))
check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check)


class PortraitCheckTests(unittest.TestCase):
    def run_check(self, described, people, published=False):
        check.traits = lambda: described
        check.fixture = lambda: people
        check.published = lambda: people
        sys.argv = ["portrait-check.py"] + (["--published"] if published else [])
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = check.main()
        return code, out.getvalue(), err.getvalue()

    def test_a_different_name_fails_and_points_at_the_slug(self):
        code, _, err = self.run_check({"ana": "Ana Souza"}, {"ana": "Bia Lima"})
        self.assertEqual(code, 1)
        self.assertIn("ana: Bia Lima in the data, Ana Souza in the traits", err)

    def test_the_same_name_with_other_accents_passes(self):
        code, out, _ = self.run_check({"ze": "José Lima"}, {"ze": "JOSE LIMA"})
        self.assertEqual(code, 0)
        self.assertIn("1 people", out)

    def test_missing_traits_only_fail_on_the_published_files(self):
        self.assertEqual(self.run_check({}, {"ana": "Ana"})[0], 0)
        self.assertEqual(self.run_check({}, {"ana": "Ana"}, published=True)[0], 1)


if __name__ == "__main__":
    unittest.main(verbosity=0)
