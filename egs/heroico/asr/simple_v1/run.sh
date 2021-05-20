#!/usr/bin/env bash

# Copyright 2020 Xiaomi Corporation (Author: Junbo Zhang)
# Apache 2.0

# Example of how to build L and G FST for K2. Most scripts of this example are copied from Kaldi.

set -eou pipefail

stage=0
# The speech corpus and lexicon are on openslr.org
#speech_url="http://www.openslr.org/resources/39/LDC2006S37.tar.gz"
lexicon_url="http://www.openslr.org/resources/34/santiago.tar.gz"
datadir=/mnt/corpora/LDC2006S37
tmpdir=data/local/tmp

if [ $stage -le 1 ]; then
  if [ ! -d $datadir ]; then
    echo "$0: please download and un-tar http://www.openslr.org/resources/39/LDC2006S37.tar.gz"
    echo "  and set $datadir to the directory where it is located."
    exit 1
  fi
  if [ ! -s santiago.txt ]; then
    echo "$0: downloading the lexicon"
    wget -c http://www.openslr.org/resources/34/santiago.tar.gz
    tar -xvzf santiago.tar.gz
  fi
fi

if [ $stage -le 2 ]; then
  python ./prepare.py
fi

if [ $stage -le 3 ]; then
  local/prepare_dict.sh
fi

if [ $stage -le 4 ]; then
  local/prepare_lang.sh \
    --position-dependent-phones false \
    data/local/dict \
    "<UNK>" \
    data/local/lang_tmp \
    data/lang
fi

if [ $stage -le 5 ]; then
  mkdir -p $tmpdir/lm
  python local/json2text.py $tmpdir/lm/text
  local/prepare_lm.sh  $tmpdir/lm/text
fi

if [ $stage -le 6 ]; then
  gunzip data/local/lm/trigram.arpa.gz
  # Build G
  python -m kaldilm \
    --read-symbol-table="data/lang/words.txt" \
    --disambig-symbol='#0' \
    --max-order=1 \
    data/local/lm/trigram.arpa >data/lang/G_uni.fst.txt

  python -m kaldilm \
    --read-symbol-table="data/lang/words.txt" \
    --disambig-symbol='#0' \
    --max-order=3 \
    data/local/lm/trigram.arpa >data/lang/G.fst.txt

  python -m kaldilm \
    --read-symbol-table="data/lang/words.txt" \
    --disambig-symbol='#0' \
    --max-order=4 \
    data/local/lm/trigram.arpa >data/lang/G_4_gram.fst.txt
fi

if [ $stage -le 7 ]; then
  python ./ctc_train.py
fi

if [ $stage -le 8 ]; then
  python ./ctc_decode.py
fi
