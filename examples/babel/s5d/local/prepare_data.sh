#!/bin/bash

# Copyright 2018 Johns Hopkins University (Matthew Wiesner)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

# This is not necessarily the top-level run.sh as it is in other directories.   see README.txt first.

. ./conf/lang.conf
. ./path.sh
. ./cmd.sh

FLP=true

. ./utils/parse_options.sh
if [ $# -ne 1 ]; then
  echo >&2 "Usage: ./local/prepare_data.sh [opts] <lang_id>"
  echo >&2 "       --FLP : Use FLP training data (instead of LLP ~10h)"
  exit 1
fi

l=$1

l_suffix=${l}
if $FLP; then
  l_suffix=${l_suffix}_FLP
fi

#Preparing train directories
echo ---------------------------------------------------------------------
echo "Subsetting the TRAIN set"
echo ---------------------------------------------------------------------
train_data_dir=train_data_dir_${l_suffix}
train_data_list=train_data_list_${l_suffix}
local/make_corpus_subset.sh "${!train_data_dir}" "${!train_data_list}" ${data}/raw_train_data_${l_suffix}
train_data_dir=`utils/make_absolute.sh ${data}/raw_train_data_${l_suffix}`
touch ${data}/raw_train_data_${l_suffix}/.done

#Preparing dev10 directories
echo ---------------------------------------------------------------------
echo "Subsetting the Dev set"
echo ---------------------------------------------------------------------
dev10h_data_dir=dev10h_data_dir_${l}
dev10h_data_list=dev10h_data_list_${l}
local/make_corpus_subset.sh "${!dev10h_data_dir}" "${!dev10h_data_list}" ${data}/raw_dev10h_data_${l_suffix}
dev10h_data_dir=`utils/make_absolute.sh ${data}/raw_dev10h_data_${l_suffix}`
touch ${data}/raw_dev10h_data_${l_suffix}/.done

dev10h_data_dir=`utils/make_absolute.sh ${data}/raw_dev10h_data_${l_suffix}`
train_data_dir=`utils/make_absolute.sh ${data}/raw_train_data_${l_suffix}`
lexicon_file=lexicon_file_${l_suffix}

echo ---------------------------------------------------------------------
echo "Preparing acoustic training lists in data/train on" `date`
echo ---------------------------------------------------------------------
mkdir -p ${data}/train.tmp
local/prepare_acoustic_training_data.pl \
  --vocab ${!lexicon_file} --fragmentMarkers \-\*\~ \
  $train_data_dir ${data}/train.tmp > ${data}/train.tmp/skipped_utts.log || exit 1;

echo ---------------------------------------------------------------------
echo "Preparing acoustic training lists in data/train on" `date`
echo ---------------------------------------------------------------------
mkdir -p ${data}/dev10h.pem
local/prepare_acoustic_training_data.pl \
  --vocab ${!lexicon_file} --fragmentMarkers \-\*\~ \
  $dev10h_data_dir ${data}/dev10h.pem > ${data}/dev10h.pem/skipped_utts.log || exit 1;



###########################################################################
# Prepend language ID to all utterances to disambiguate between speakers
# of different languages sharing the same speaker id.
#
# The individual lang directories can be used for alignments, while a
# combined directory will be used for training. This probably has minimal
# impact on performance as only words repeated across languages will pose
# problems and even amongst these, the main concern is the <hes> marker.
###########################################################################

num_utts=$(cat ${data}/train.tmp/segments | wc -l)
dev_utts=$((num_utts / 100))  # use 1%

./utils/subset_data_dir.sh ${data}/train.tmp ${dev_utts} ${data}/dev

awk '{print $1}' ${data}/dev/utt2spk > ${data}/dev.list
awk '{print $1}' ${data}/train.tmp/utt2spk | grep -vf ${data}/dev.list > ${data}/train.list

./utils/subset_data_dir.sh --utt-list ${data}/train.list ${data}/train.tmp ${data}/train

echo "Prepend ${l} to data dir"
./utils/copy_data_dir.sh --spk-prefix "${l}_" --utt-prefix "${l}_" \
  ${data}/train ${data}/train_${l}

./utils/copy_data_dir.sh --spk-prefix "${l}_" --utt-prefix "${l}_" \
  ${data}/dev ${data}/dev_${l}

./utils/copy_data_dir.sh --spk-prefix "${l}_" --utt-prefix "${l}_" \
  ${data}/dev10h.pem ${data}/eval_${l}