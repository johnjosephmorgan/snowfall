#!/usr/bin/env bash
# Copied from the librispeech recipe
# Copyright 2020 Xiaomi Corporation (Author: Junbo Zhang)
# Apache 2.0

# Example of how to build L and G FST for K2. Most scripts of this example are copied from Kaldi.

set -eou pipefail

stage=0

# location of language model and lexicon
lm=/mnt/corpora/MLS_French/trigram.arpa.gz
dict=/mnt/corpora/MLS_French/santiago.txt

if [ $stage -le 1 ]; then
  # Get the lm
  mkdir -p data/local/lm
  cp $lm data/local/lm
  (
    cd data/local/lm
    gunzip -c trigram.arpa.gz > lm_tgmed.arpa
  )
fi

if [ $stage -le 2 ]; then
  # Prepare the lexicon
  local/prepare_dict.sh \
    $dict \
    data/local/dict || exit 1;
fi

if [ $stage -le 3 ]; then
  # Prepare the lexicon fst
  local/prepare_lang.sh \
    --position-dependent-phones false \
    data/local/dict \
    "<UNK>" \
    data/local/lang_tmp \
    data/lang

  echo "To load L:"
  echo "    Lfst = k2.Fsa.from_openfst(<string of data/lang/L.fst.txt>, acceptor=False)"
fi

if [ $stage -le 4 ]; then
  # Build G
  python -m kaldilm \
    --read-symbol-table="data/lang/words.txt" \
    --disambig-symbol='#0' \
    --max-order=1 \
    data/local/lm/lm_tgmed.arpa >\
    data/lang/G_uni.fst.txt

  python -m kaldilm \
    --read-symbol-table="data/lang/words.txt" \
    --disambig-symbol='#0' \
    --max-order=3 \
    data/local/lm/lm_tgmed.arpa >\
    data/lang/G.fst.txt

  echo "To load G:"
  echo "Use::"
  echo "  with open('data/lang/G.fst.txt') as f:"
  echo "    G = k2.Fsa.from_openfst(f.read(), acceptor=False)"
  echo ""
fi

if [ $stage -le 5 ]; then
  python ./prepare.py
fi

if [ $stage -le 6 ]; then
  # python ./train.py # ctc training
  # python ./mmi_bigram_train.py # ctc training + bigram phone LM
  #  python ./mmi_mbr_train.py

  # Single node, multi-GPU training
  # Adapting to a multi-node scenario should be straightforward.
  ngpus=2
  python -m torch.distributed.launch --nproc_per_node=$ngpus ./mmi_bigram_train.py --world_size $ngpus
fi

if [ $stage -le 7 ]; then
  # python ./decode.py # ctc decoding
  python ./mmi_bigram_decode.py --epoch 9
  #  python ./mmi_mbr_decode.py
fi
