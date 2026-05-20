// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PulseTESTY
/// @notice Meridian tape for telemetered crowd-throb: lanes hold tempo-weighted sentiment needles.
/// @dev No custody. Needles are observational. Caps and cooldowns reduce spam; epochs bookmark drift.

contract PulseTESTY {

    enum GaugeWeave {
        MacroTape,
        AltcoinRipple,
        MemeDraft,
        DefiVapor,
        L2Static,
        RwaGlide,
        AiHum,
        ChaosLint
    }

    enum SwayPolarity { Iceward, Sunward, NeutralBias }

    struct PulseSlice {
        int32 needle;
        uint32 mass;
        uint48 stamped;
        address scribe;
        bytes32 captionHash;
    }

    struct OrbitStats {
        int256 accNeedle;
        uint256 accMass;
        uint32 samples;
        uint32 lastStamp;
    }

    struct PublisherCapsule {
        bool allowed;
        uint32 dayBucket;
        uint16 dayTally;
        uint32 cooldownUntil;
        uint64 lifetimeWrites;
    }

    struct EpochMarker {
        uint64 id;
        uint48 opened;
        uint48 sealed;
        int24 carryMacro;
        int24 carryMeme;
    }

    address private _chief;
    address private _pendingChief;

    address public immutable ADDRESS_A;
    address public immutable ADDRESS_B;
    address public immutable ADDRESS_C;
    address public immutable ADDRESS_D;

    bytes32 public constant PTY_DOMAIN_CORD =
        0x440e0e69248e9a5fa937dc42ec87a0d24837d14af198f3d348e82f71d8441ded;
    bytes32 public constant PTY_HORIZON_MARK =
        0x585ae42661f5556b0555ec5e75b592ef15227533c63c35c0fcb8841848320676;
    bytes16 public constant PTY_BEACON_TAG = 0x680df5adabc24f357d8979cef4b5865c;
    bytes16 public constant PTY_AUX_GLINT = 0xc8a409e781f49d311d20e9ee5321d3d5;
    uint64 public constant PTY_FABRIC_SIG = 0xbfdb1c397ed5b541;
    uint64 public constant PTY_GRID_REF = 0x541256d41177;
    uint32 public constant PTY_SKU_PAD = 939742784;
    uint32 public constant PTY_FAN_INDEX = 628325;

    uint16 public constant PTY_RING_SPAN = 103;
    uint16 public constant PTY_LANE_COUNT = 8;
    int32 public constant PTY_NEEDLE_CEIL = 1_000_000;
    uint32 public constant PTY_MASS_FLOOR = 1;
    uint32 public constant PTY_MASS_CEIL = 9_500_000;
    uint16 public constant PTY_DAILY_PULSE_CAP = 244;
    uint32 public constant PTY_COOLDOWN_SEC = 41;
    uint16 public constant PTY_BATCH_CEIL = 36;

    bool public gaugeHalted;
    uint64 public epochCounter;
    uint48 public lastGlobalPulse;
    uint32 public decayHalfLifeSec;

    mapping(address => PublisherCapsule) private _publishers;
    mapping(uint8 => mapping(uint16 => PulseSlice)) private _rings;
    mapping(uint8 => uint16) private _heads;
    mapping(uint8 => uint16) private _counts;
    mapping(uint8 => OrbitStats) private _orbits;
    mapping(uint64 => EpochMarker) private _epochs;

    error PTY_NotChief(address caller);
    error PTY_NotPending(address caller);
    error PTY_Halted();
    error PTY_PublisherDenied(address who);
    error PTY_NeedleBounds(int32 got);
    error PTY_MassBounds(uint32 got);
    error PTY_LaneInvalid(uint8 lane);
    error PTY_DailyCap(address who, uint16 tally);
    error PTY_CooldownHot(address who, uint32 until);
    error PTY_BatchUneven();
    error PTY_BatchEmpty();
    error PTY_BatchHuge();
    error PTY_CaptionZero();
    error PTY_ZeroPeer(address peer);
    error PTY_EpochGhost(uint64 id);
    error PTY_DecayOutOfBand(uint32 got);
    error PTY_EthRefused();
    error PTY_RingCursor(uint16 cursor);

    event PTY_ChiefHandoffQueued(address indexed chief, address indexed pending);
    event PTY_ChiefTransferred(address indexed former, address indexed incoming);
    event PTY_PublisherFlag(address indexed who, bool allowed);
    event PTY_GaugePause(address indexed chief, bool halted);
    event PTY_PulseWritten(uint8 indexed lane, address indexed scribe, int32 needle, uint32 mass, uint48 stamped);
    event PTY_OrbitSynced(uint8 indexed lane, int256 accNeedle, uint256 accMass, uint32 samples);
    event PTY_EpochOpened(uint64 indexed epoch, uint48 opened, int24 carryMacro, int24 carryMeme);
    event PTY_EpochSealed(uint64 indexed epoch, uint48 sealed);
    event PTY_DecayKnobTuned(uint32 halfLifeSeconds);
    event PTY_AuxBeaconPing(bytes16 aux, uint32 fanIdx);

    modifier onlyChief() {
        if (msg.sender != _chief) revert PTY_NotChief(msg.sender);
        _;
    }

    modifier whenLive() {
        if (gaugeHalted) revert PTY_Halted();
        _;
    }

    constructor() {
        ADDRESS_A = 0x8ED417DD97500db38a5502f009A349A6B3DE75b4;
        ADDRESS_B = 0x6C820eAA609246a14eA372BbCCa6d2041c60E0Dc;
        ADDRESS_C = 0x157C365282ea751c4756A2cA03062501DcD6F20C;
        ADDRESS_D = 0xC313AFd9bE39032C655B03C1e549ddf37A619Ea9;
        _chief = msg.sender;
        decayHalfLifeSec = 6_600;
        epochCounter = 1;
        _epochs[1] = EpochMarker({
            id: 1,
            opened: uint48(block.timestamp),
            sealed: 0,
            carryMacro: 0,
            carryMeme: 0
        });
        _publishers[msg.sender].allowed = true;
        emit PTY_EpochOpened(1, uint48(block.timestamp), 0, 0);
        emit PTY_AuxBeaconPing(PTY_AUX_GLINT, PTY_FAN_INDEX);
    }

    receive() external payable {
        revert PTY_EthRefused();
    }

    fallback() external payable {
        revert PTY_EthRefused();
    }

    function chief() external view returns (address) {
        return _chief;
    }

    function pendingChief() external view returns (address) {
        return _pendingChief;
    }

    function queueChiefHandoff(address next) external onlyChief {
        if (next == address(0)) revert PTY_ZeroPeer(next);
        _pendingChief = next;
        emit PTY_ChiefHandoffQueued(_chief, next);
    }

    function acceptChief() external {
        if (msg.sender != _pendingChief) revert PTY_NotPending(msg.sender);
        address former = _chief;
        _chief = msg.sender;
        _pendingChief = address(0);
        emit PTY_ChiefTransferred(former, msg.sender);
    }

    function setPublisher(address who, bool permitted) external onlyChief {
        if (who == address(0)) revert PTY_ZeroPeer(who);
        _publishers[who].allowed = permitted;
        emit PTY_PublisherFlag(who, permitted);
    }

    function setGaugeHalt(bool halt) external onlyChief {
        gaugeHalted = halt;
        emit PTY_GaugePause(msg.sender, halt);
    }

    function tuneDecayHalfLife(uint32 secondsHalf) external onlyChief {
        if (secondsHalf < 120 || secondsHalf > 86_400) revert PTY_DecayOutOfBand(secondsHalf);
        decayHalfLifeSec = secondsHalf;
        emit PTY_DecayKnobTuned(secondsHalf);
    }

    function sealAndOpenEpoch(int24 macroHint, int24 memeHint) external onlyChief {
        uint64 id = epochCounter;
        EpochMarker storage era = _epochs[id];
        if (era.opened == 0) revert PTY_EpochGhost(id);
        era.sealed = uint48(block.timestamp);
        emit PTY_EpochSealed(id, era.sealed);
        unchecked {
            epochCounter += 1;
        }
        uint64 nid = epochCounter;
        _epochs[nid] = EpochMarker({
            id: nid,
            opened: uint48(block.timestamp),
            sealed: 0,
            carryMacro: macroHint,
            carryMeme: memeHint
        });
        emit PTY_EpochOpened(nid, uint48(block.timestamp), macroHint, memeHint);
    }

    function publisherProfile(address who) external view returns (PublisherCapsule memory) {
        return _publishers[who];
    }

    function orbitOf(uint8 lane) external view returns (OrbitStats memory) {
        _requireLane(lane);
        return _orbits[lane];
    }

    function epochOf(uint64 id) external view returns (EpochMarker memory) {
        return _epochs[id];
    }

    function recordPulse(uint8 lane, int32 needle, uint32 mass, bytes32 captionHash) public whenLive {
        _writePulse(msg.sender, lane, needle, mass, captionHash);
    }

    function recordPulseBatch(
        uint8[] calldata lanes,
        int32[] calldata needles,
        uint32[] calldata masses,
        bytes32[] calldata captions
    ) external whenLive {
        uint256 n = lanes.length;
        if (n == 0) revert PTY_BatchEmpty();
        if (n > PTY_BATCH_CEIL) revert PTY_BatchHuge();
        if (n != needles.length || n != masses.length || n != captions.length) {
            revert PTY_BatchUneven();
        }
        for (uint256 i = 0; i < n; ) {
            _writePulse(msg.sender, lanes[i], needles[i], masses[i], captions[i]);
            unchecked {
                ++i;
            }
        }
    }

    function laneWeightedNeedle(uint8 lane) external view returns (int128) {
        _requireLane(lane);
        OrbitStats memory o = _orbits[lane];
        if (o.accMass == 0) return 0;
        int256 avg = o.accNeedle / int256(o.accMass);
        if (avg > type(int128).max) return type(int128).max;
        if (avg < type(int128).min) return type(int128).min;
