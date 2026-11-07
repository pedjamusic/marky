#ifndef MARKY_DOCUMENT_TEST_CHECKPOINTS_H
#define MARKY_DOCUMENT_TEST_CHECKPOINTS_H

namespace marky::test {

enum class Checkpoint {
    beforeTokenAllocation,
    beforeDocumentAllocation,
    beforeDocumentPublication
};

void checkpoint(Checkpoint point);
void document_destroyed() noexcept;

}

#endif
