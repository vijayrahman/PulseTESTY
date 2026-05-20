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
