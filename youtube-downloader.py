from pytubefix import YouTube
from argparse import ArgumentParser


def download_video(url: str, path: str, audio_only: bool = False):
    video = YouTube(url)
    if audio_only:
        stream = video.streams.get_audio_only()
    else:
        stream = video.streams.get_highest_resolution()
    stream.download(output_path=path)


if __name__ == "__main__":
    parser = ArgumentParser("Automatic YouTube Video downloader")
    parser.add_argument("url", help="URL from YouTube video to download")
    parser.add_argument(
        "-p",
        "--path",
        type=str,
        default="output",
        help="Output path to save the file to",
    )
    parser.add_argument(
        "--audio_only",
        action="store_true",
        help="Download only the audio track and not the video",
    )

    args = parser.parse_args()
    download_video(args.url, args.path, args.audio_only)
