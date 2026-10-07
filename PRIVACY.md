# Privacy Policy — Flock Surveillance

**Last updated: October 6, 2026**

Flock Surveillance is a civic transparency app that maps community-documented ALPR (automated
license plate reader) camera locations from OpenStreetMap. It is not affiliated with Flock Safety.

**The developer receives no data.** There are no accounts, no analytics, no advertising, no
tracking, and no developer-operated servers. Nothing you do in this app is sent to us, because
there is nowhere for it to go. To load camera pins, the app does ask public OpenStreetMap servers
for a rough area around you. That is described below.

## Location

The app requests location access to show nearby mapped cameras, run Drive Mode, and — if you turn
it on — send geofenced alerts when you approach a mapped camera.

**Your precise location stays on your phone.** It is never sent to the developer, never stored
off device, and never shared or sold.

To load pins, the app asks public OpenStreetMap servers for camera data in a **rough area** around
you, never your exact spot. Every request is rounded outward to a fixed grid of about 10 km
(0.1° of latitude and longitude), so the area is the same for everyone in that grid square and is
never centered on you. No account, name, or device identifier is attached.

If you grant Always access, background location is used solely for the optional proximity alerts
described above, and only while that feature is enabled.

Location permission can be revoked at any time in iOS Settings. The app remains usable without it.

## Camera

Camera access is used only by AR Camera Sight, which overlays mapped camera locations onto the
live viewfinder. The video feed stays on your device. Nothing is recorded, saved, or uploaded.

The app cannot see through, access, or receive video from any ALPR or surveillance camera. It
knows only your phone's GPS position relative to a location mapped in OpenStreetMap.

## Network requests

The app makes network requests to these third parties. None of them receive your identity, an
account, or a device identifier.

- **OpenStreetMap / Overpass API** — the app requests camera data by sending a geographic
  bounding box. The box is snapped outward to a fixed ~10 km grid, so it reveals only a rough
  area (for example, the grid square around you or the part of the map you are viewing), never
  your precise position. It is not linked to you. Like any web request, the server sees your IP
  address; see the [OpenStreetMap privacy policy](https://osmfoundation.org/wiki/Privacy_Policy).
- **Wisconsin DOT** (`content.dot.wi.gov`, `www.dot.wi.gov`) — if you open the detail view for a
  municipal traffic camera in the optional Sensor Atlas layer, the app loads a publicly available
  traveler-information still image from these hosts. This happens only when you tap that specific
  pin. These are public traffic cameras, not ALPR or Flock cameras, and the images are not
  recorded by the app.
- **Apple Maps** — map tiles and driving directions are provided by MapKit and governed by
  [Apple's privacy policy](https://www.apple.com/legal/privacy/).

## Community reporting

If you choose to report an unmapped or incorrect camera, the app submits an anonymous note to
OpenStreetMap containing the location and any description you write. This is a deliberate,
user-initiated action, and the submission is public — it becomes part of the OpenStreetMap
record. No personal information or account is attached. Do not include personal details in a
report. See the [OpenStreetMap privacy policy](https://osmfoundation.org/wiki/Privacy_Policy).

## Tips

An optional tip jar in Settings lets you send a one-time tip through Apple In-App Purchase.
Apple processes the payment. We do not receive your card number, and we do not send receipts
or transaction data to a developer server. A tip unlocks nothing. The app stays free either way.

## On-device storage

Cached camera data, your preferences, and any Home or Work locations you set are stored on your
device and in a shared app group so the Home Screen widget can read them. This data stays on
your device and is deleted when you delete the app. Cached camera data can be cleared at any time
from Settings.

## Children

The app is not directed at children. The developer receives no data from anyone, including children.

## Data disclosure requests

We hold no user data, so there is none to disclose, sell, or hand over in response to any request.

## Changes

Material changes to this policy will be published on this page with an updated date.

## Map data

Camera locations come from OpenStreetMap. Map data © OpenStreetMap contributors, available
under the Open Database License: <https://www.openstreetmap.org/copyright>.

## Contact

Questions: [flocksurveillance.com](https://flocksurveillance.com)
