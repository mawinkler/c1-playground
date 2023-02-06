#!/bin/bash
mkdocs build
mv site ../playground-pages/
rm -rf ../playground-pages/docs
mv ../playground-pages/site ../playground-pages/docs
