#!/usr/bin/env bash

# Copyright 2020 Xiaomi Corporation (Author: Junbo Zhang)
# Apache 2.0

# Example of how to build L and G FST for K2. Most scripts of this example are copied from Kaldi.

set -eou pipefail

stage=0
# The speech corpus and lexicon are on openslr.org
#speech_url="http://www.openslr.org/resources/39/LDC2006S37.tar.gz"
lexicon_url="http://www.openslr.org/resources/34/santiago.tar.gz"
# Location of the Movie subtitles text corpus
subtitles_url="http://opus.lingfil.uu.se/download.php?f=OpenSubtitles2018/en-es.txt.zip"
datadir=/mnt/corpora/LDC2006S37
# don't change tmpdir, the location is used explicitly in scripts in local/.
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
  # Get data for lm training
  local/subs_download.sh $subtitles_url
fi

if [ $stage -le 2 ]; then
  local/prepare_dict.sh
  #local/prepare_dict.sh data/local/lm data/local/dict_nosp
fi

if [ $stage -le 3 ]; then
  local/prepare_lang.sh \
    --position-dependent-phones false \
    data/local/dict \
    "<UNK>" \
    data/local/lang_tmp \
    data/lang

  echo "To load L:"
  echo "    Lfst = k2.Fsa.from_openfst(<string of data/lang_nosp/L.fst.txt>, acceptor=False)"
fi

if [ $stage -le 4 ]; then
  # Build G
  python3 -m kaldilm \
    --read-symbol-table="data/lang_nosp/words.txt" \
    --disambig-symbol='#0' \
    --max-order=1 \
    data/local/lm/lm_tgmed.arpa >data/lang_nosp/G_uni.fst.txt

  python3 -m kaldilm \
    --read-symbol-table="data/lang_nosp/words.txt" \
    --disambig-symbol='#0' \
    --max-order=3 \
    data/local/lm/lm_tgmed.arpa >data/lang_nosp/G.fst.txt

  python3 -m kaldilm \
    --read-symbol-table="data/lang_nosp/words.txt" \
    --disambig-symbol='#0' \
    --max-order=4 \
    data/local/lm/lm_fglarge.arpa >data/lang_nosp/G_4_gram.fst.txt

  echo ""
  echo "To load G:"
  echo "Use::"
  echo "  with open('data/lang_nosp/G.fst.txt') as f:"
  echo "    G = k2.Fsa.from_openfst(f.read(), acceptor=False)"
  echo ""
fi

if [ $stage -le 5 ]; then
  python3 ./prepare.py
fi

if [ $stage -le 6 ]; then
  # python3 ./train.py # ctc training
  # python3 ./mmi_bigram_train.py # ctc training + bigram phone LM
  #  python3 ./mmi_mbr_train.py

  # Single node, multi-GPU training
  # Adapting to a multi-node scenario should be straightforward.
  ngpus=2
  python3 -m torch.distributed.launch --nproc_per_node=$ngpus ./mmi_bigram_train.py --world_size $ngpus
fi

if [ $stage -le 7 ]; then
  # python3 ./decode.py # ctc decoding
  python3 ./mmi_bigram_decode.py --epoch 9
  #  python3 ./mmi_mbr_decode.py
fi
