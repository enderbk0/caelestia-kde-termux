#pragma once

#include <qqmlintegration.h>

#include "audioprovider.hpp"

#if CAELESTIA_HAS_AUBIO

#include <aubio/aubio.h>

namespace caelestia::services {

class BeatProcessor : public AudioProcessor {
    Q_OBJECT

public:
    explicit BeatProcessor(QObject* parent = nullptr);
    ~BeatProcessor();

signals:
    void beat(smpl_t bpm);

protected:
    void process() override;

private:
    aubio_tempo_t* m_tempo;
    fvec_t* m_in;
    fvec_t* m_out;
};

} // namespace caelestia::services

#else // !CAELESTIA_HAS_AUBIO

namespace caelestia::services {

class BeatProcessor : public AudioProcessor {
    Q_OBJECT

public:
    explicit BeatProcessor(QObject* parent = nullptr);
    ~BeatProcessor();

signals:
    void beat(float bpm);

protected:
    void process() override;
};

} // namespace caelestia::services

#endif // CAELESTIA_HAS_AUBIO

namespace caelestia::services {

class BeatTracker : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(float bpm READ bpm NOTIFY bpmChanged)

public:
    explicit BeatTracker(QObject* parent = nullptr);

    [[nodiscard]] float bpm() const;

signals:
    void bpmChanged();
    void beat(float bpm);

private:
    float m_bpm;

    void updateBpm(float bpm);
};

} // namespace caelestia::services
