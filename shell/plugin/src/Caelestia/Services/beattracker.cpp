#include "beattracker.hpp"

#include "audiocollector.hpp"
#include "audioprovider.hpp"

#if CAELESTIA_HAS_AUBIO

#include <aubio/aubio.h>

namespace caelestia::services {

BeatProcessor::BeatProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_tempo(new_aubio_tempo("default", 1024, ac::CHUNK_SIZE, ac::SAMPLE_RATE))
    , m_in(new_fvec(ac::CHUNK_SIZE))
    , m_out(new_fvec(2)) {};

BeatProcessor::~BeatProcessor() {
    if (m_tempo) {
        del_aubio_tempo(m_tempo);
    }
    if (m_in) {
        del_fvec(m_in);
    }
    if (m_out) {
        del_fvec(m_out);
    }
}

void BeatProcessor::process() {
    if (!m_tempo || !m_in) {
        return;
    }

    AudioCollector::instance().readChunk(m_in->data);

    aubio_tempo_do(m_tempo, m_in, m_out);
    if (!qFuzzyIsNull(m_out->data[0])) {
        emit beat(aubio_tempo_get_bpm(m_tempo));
    }
}

} // namespace caelestia::services

#else // !CAELESTIA_HAS_AUBIO

namespace caelestia::services {

BeatProcessor::BeatProcessor(QObject* parent)
    : AudioProcessor(parent) {}

BeatProcessor::~BeatProcessor() = default;

void BeatProcessor::process() {}

} // namespace caelestia::services

#endif // CAELESTIA_HAS_AUBIO

namespace caelestia::services {

BeatTracker::BeatTracker(QObject* parent)
    : AudioProvider(parent)
    , m_bpm(0) {
    m_processor = new BeatProcessor();
    init();

    connect(static_cast<BeatProcessor*>(m_processor), &BeatProcessor::beat, this, &BeatTracker::updateBpm);
}

float BeatTracker::bpm() const {
    return m_bpm;
}

void BeatTracker::updateBpm(float bpm) {
    if (!qFuzzyCompare(bpm + 1.0f, m_bpm + 1.0f)) {
        m_bpm = bpm;
        emit bpmChanged();
    }
}

} // namespace caelestia::services
