# `ffmpeg-insert-first-frame.sh`

Inserts a given thumbnail image to a video file.  
Without reencoding or messing with the video!

## Usage

```bash
./ffmpeg-insert-first-frame.sh thumb.jpg video.mp4
    Codec: hevc
Dimension: 1702x952
Framerate: 60.00000000000000000000

==> Generating single frame thumbnail video... ✅

==> Converting videos to MPEG-TS container...
Thumb... ✅
Video... ✅

==> Concatenating... ✅

Done!
Output: video-combined.mp4

```

## Details
This works by remuxing the video container format to MPEG-TS, which can be concatenated nicely with `ffmpeg`.  
An MP4 video with HEVC/H264 can be trivially remuxed to MPEG-TS, so this is very nice.

```mermaid
graph LR
    T0[thumb.jpg]
    subgraph T1["thumb.mp4"]
        st1[thumb.jpg<br>Stream]
    end
    subgraph T2["thumb.ts"]
        st2[thumb.jpg<br>Stream]
    end
    T0 --> T1
    st1 --> st2

    subgraph V1["video.mp4"]
        sv1[video.mp4<br>Stream]
    end
    subgraph V2["video.ts"]
        sv2[video.mp4<br>Stream]
    end
    V0 ~~~ V1
    sv1 --> sv2

    subgraph O["video-combined.mp4"]
        sto["thumb.jpg<br>Stream"]
        svo["video.mp4<br>Stream"]
    end
    st2 --> sto
    sv2 --> svo
    
    classDef hidden fill:transparent,stroke:transparent,color:transparent
    class V0 hidden

    classDef mp4 fill:#bdf
    class T1 mp4
    class V1 mp4
    class O mp4

    classDef ts fill:#ffb
    class T2 ts
    class V2 ts
```



