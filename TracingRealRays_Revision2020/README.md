# Sources for "Tracing real rays", Revision 2020 (wild-category) entry by Nupo
(https://www.pouet.net/prod.php?which=85274)

This directory includes:
- Raw data captured from the GNSS-receivers (UBX-format) and the distance 
  measurement module. No data from the base as it's not needed here. 
  Receivers were configured to output only relative coordinates in 
  "RELPOSNED"-messages so there's no absolute position available.
- "movie script" that the Processing-sketch uses. Generated using the 
  "GNSS-stylus"-program (can be found from github)
- XYZ point clouds generated from the raw data (and tags)
- Obj-files generated from the point clouds (using MeshLab)
- Processing sketch (version 3.5.4 used) used to generate the CGI-parts of 
  the video

Running the processing sketch "ToiletSeat_Processing/ToiletSeat_Processing.pde"
should start rotating a toilet seat (and accessories) on your screen. There 
are some swithes gathered to the top of the sketch that can be used to modify 
the rendered scene, most influential ones being "cameraType" and 
"scriptReplaySpeed".

File "Logs/Toilet_tags_original_unedited.tags" contains the original tags
added while "raytracing". It has more tags than the edited one. Data in the 
end of the files is, however, corrupted. Battery of the laptop used for 
scanning died and after restarting it using a car battery and inverter data 
was no longer plausible. Probably caused by the inverter and laptop's power 
supply being right next to the base's GNSS-receiver, causing too much noise.

Paper reel and brush were "raytraced" separately later (and in different
coordinates), no scanning data available for them.
