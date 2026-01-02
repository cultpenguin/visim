!-----------------------------------------------------------------------
! VISIM F90 Parameter Reader
! ---------------------------
! Two-pass parameter reading for dynamic allocation:
!   Pass 1 (readparm_get_dimensions): Extract dimension requirements
!   Pass 2 (readparm_populate):       Fill allocated arrays with data
!
! Supports both:
!   - Legacy format (line-based, "START OF PARAMETERS" marker)
!   - New keyword format (key=value pairs, [SECTIONS])
!-----------------------------------------------------------------------

module visim_readpar_v2
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_kriging_mod
  use visim_search_mod
  use visim_histogram_mod
  use visim_random_mod
  implicit none

  integer, parameter :: MAX_LINE_LEN = 512
  character(len=MAX_LINE_LEN) :: parfile_name
  integer :: format_type  ! 1=legacy, 2=keyword

contains

!-----------------------------------------------------------------------
! readparm_get_dimensions - First pass: determine array sizes
!-----------------------------------------------------------------------
subroutine readparm_get_dimensions(maxdat, maxvols, maxdinvol, &
                                    maxnod, maxsam, maxnst, &
                                    maxctx, maxcty, maxctz, &
                                    maxsbx, maxsby, maxsbz, &
                                    maxquan, maxmvlook, maxref, maxcat)
  integer, intent(out) :: maxdat, maxvols, maxdinvol
  integer, intent(out) :: maxnod, maxsam, maxnst
  integer, intent(out) :: maxctx, maxcty, maxctz
  integer, intent(out) :: maxsbx, maxsby, maxsbz
  integer, intent(out) :: maxquan, maxmvlook, maxref, maxcat

  character(len=MAX_LINE_LEN) :: str
  logical :: testfl
  integer :: argc, ndmax_tmp, nodmax_tmp

  ! Get parameter file name from command line or user
  call get_parameter_filename(parfile_name)

  ! Store for later use by populate function
  call set_parfile_for_populate(parfile_name)

  ! Check if file exists
  inquire(file=parfile_name, exist=testfl)
  if (.not. testfl) then
    write(*,*) 'ERROR: Parameter file does not exist: ', trim(parfile_name)
    write(*,*) '       Creating blank template...'
    call makepar_v2()
    stop 'Please edit the parameter file and run again'
  end if

  ! Detect format
  call detect_format(parfile_name, format_type)

  if (format_type == 2) then
    write(*,*) 'Detected NEW keyword-based parameter format'
    call read_dimensions_keyword(maxdat, maxvols, maxdinvol, &
                                   maxnod, maxsam, maxnst, &
                                   maxctx, maxcty, maxctz, &
                                   maxsbx, maxsby, maxsbz, &
                                   maxquan, maxmvlook, maxref, maxcat)
  else
    write(*,*) 'Detected LEGACY line-based parameter format'
    call read_dimensions_legacy(maxdat, maxvols, maxdinvol, &
                                  maxnod, maxsam, maxnst, &
                                  maxctx, maxcty, maxctz, &
                                  maxsbx, maxsby, maxsbz, &
                                  maxquan, maxmvlook, maxref, maxcat)
  end if

  ! Validate dimensions
  if (nx <= 0 .or. ny <= 0 .or. nz <= 0) then
    write(*,*) 'ERROR: Invalid grid dimensions: ', nx, ny, nz
    stop 'INVALID_DIMENSIONS'
  end if

  write(*,*) 'Dimension requirements determined:'
  write(*,'(A,I0,A,I0,A,I0)') '  Grid: ', nx, ' x ', ny, ' x ', nz
  write(*,'(A,I0)') '  Max data: ', maxdat
  write(*,'(A,I0,A,I0)') '  Max volumes: ', maxvols, ' (points/vol: ', maxdinvol, ')'
  write(*,'(A,I0,A,I0)') '  Kriging: nodes=', maxnod, ', samples=', maxsam

end subroutine readparm_get_dimensions

!-----------------------------------------------------------------------
! read_dimensions_legacy - Extract dimensions from legacy format
!-----------------------------------------------------------------------
subroutine read_dimensions_legacy(maxdat, maxvols, maxdinvol, &
                                    maxnod, maxsam, maxnst, &
                                    maxctx, maxcty, maxctz, &
                                    maxsbx, maxsby, maxsbz, &
                                    maxquan, maxmvlook, maxref, maxcat)
  integer, intent(out) :: maxdat, maxvols, maxdinvol
  integer, intent(out) :: maxnod, maxsam, maxnst
  integer, intent(out) :: maxctx, maxcty, maxctz
  integer, intent(out) :: maxsbx, maxsby, maxsbz
  integer, intent(out) :: maxquan, maxmvlook, maxref, maxcat

  character(len=MAX_LINE_LEN) :: str
  integer :: lin_tmp, ndmax_tmp, nodmax_tmp
  real :: radius_tmp

  lin_tmp = 99
  open(lin_tmp, file=parfile_name, status='OLD')

  ! Find START marker
  do
    read(lin_tmp, '(a4)', end=99) str(1:4)
    if (str(1:4) == 'STAR') exit
  end do

  ! Read key parameters to determine dimensions (line by line per original format)
  read(lin_tmp, *, end=99, err=99) icond  ! Line 1: conditional simulation flag
  read(lin_tmp, '(a)', end=99, err=99) str  ! Line 2: data file
  read(lin_tmp, *, end=99, err=99) ! Line 3: column indices
  read(lin_tmp, '(a)', end=99, err=99) str  ! Line 4: volgeom file
  read(lin_tmp, '(a)', end=99, err=99) str  ! Line 5: volsum file
  read(lin_tmp, *, end=99, err=99) ! Line 6: tmin, tmax
  read(lin_tmp, *, end=99, err=99) idbg  ! Line 7: debug level
  read(lin_tmp, '(a)', end=99, err=99) str  ! Line 8: output file
  read(lin_tmp, *, end=99, err=99) nsim  ! Line 9: number of realizations
  read(lin_tmp, *, end=99, err=99) idrawopt  ! Line 10: distribution type
  read(lin_tmp, '(a)', end=99, err=99) str  ! Line 11: reference histogram file
  read(lin_tmp, *, end=99, err=99) ! Line 12: columns for ref histogram
  read(lin_tmp, *, end=99, err=99) ! Line 13: min/max Gmean, n_Gmean
  read(lin_tmp, *, end=99, err=99) ! Line 14: min/max Gvar, n_Gvar
  read(lin_tmp, *, end=99, err=99) ! Line 15: nQ, do_discrete

  ! Read grid dimensions (lines 16-18)
  read(lin_tmp, *, end=99, err=99) nx, xmn, xsiz  ! Line 16
  read(lin_tmp, *, end=99, err=99) ny, ymn, ysiz  ! Line 17
  read(lin_tmp, *, end=99, err=99) nz, zmn, zsiz  ! Line 18

  nxy = nx * ny
  nxyz = nx * ny * nz

  ! Continue reading to get search parameters
  read(lin_tmp, *, end=99, err=99) ! Line 19: random seed
  read(lin_tmp, *, end=99, err=99) ndmax_tmp, nodmax_tmp  ! Line 20: min/max data
  read(lin_tmp, *, end=99, err=99) ! Line 21: simulated nodes to use
  read(lin_tmp, *, end=99, err=99) ! Line 22: volume neighborhood
  read(lin_tmp, *, end=99, err=99) ! Line 23: random path
  read(lin_tmp, *, end=99, err=99) ! Line 24: assign data to nodes
  read(lin_tmp, *, end=99, err=99) ! Line 25: max data per octant
  read(lin_tmp, *, end=99, err=99) radius_tmp  ! Line 26: search radii

  close(lin_tmp)

  ! Set dimension parameters with safety margins
  maxdat = 50000         ! Conservative default
  maxnod = max(nodmax_tmp, 1448)
  maxsam = max(ndmax_tmp, 148)
  maxnst = 4             ! Standard max structures
  maxvols = 805          ! Standard volume count
  maxdinvol = 199        ! Standard points per volume
  maxquan = 501          ! DSSIM quantiles
  maxmvlook = 201        ! DSSIM lookup table
  maxref = 10000         ! Reference distribution
  maxcat = 24            ! Categories

  ! Covariance table dimensions (match grid)
  maxctx = nx
  maxcty = ny
  maxctz = nz

  ! Super block dimensions (standard defaults)
  maxsbx = 21
  maxsby = 21
  maxsbz = 11

  return

99 write(*,*) 'ERROR: Failed to read dimensions from legacy parameter file'
   close(lin_tmp)
   stop 'READ_ERROR'

end subroutine read_dimensions_legacy

!-----------------------------------------------------------------------
! read_dimensions_keyword - Extract dimensions from keyword format
!-----------------------------------------------------------------------
subroutine read_dimensions_keyword(maxdat, maxvols, maxdinvol, &
                                     maxnod, maxsam, maxnst, &
                                     maxctx, maxcty, maxctz, &
                                     maxsbx, maxsby, maxsbz, &
                                     maxquan, maxmvlook, maxref, maxcat)
  integer, intent(out) :: maxdat, maxvols, maxdinvol
  integer, intent(out) :: maxnod, maxsam, maxnst
  integer, intent(out) :: maxctx, maxcty, maxctz
  integer, intent(out) :: maxsbx, maxsby, maxsbz
  integer, intent(out) :: maxquan, maxmvlook, maxref, maxcat

  character(len=MAX_LINE_LEN) :: line, key, value
  integer :: lin_tmp, ierr, ndmax_tmp, nodmax_tmp
  logical :: in_dimensions, in_grid, in_search

  lin_tmp = 99
  open(lin_tmp, file=parfile_name, status='OLD')

  ! Initialize flags
  in_dimensions = .false.
  in_grid = .false.
  in_search = .false.
  nodmax_tmp = 12
  ndmax_tmp = 8

  ! Initialize dimension outputs to zero (will be set to defaults later)
  maxdat = 0
  maxvols = 0
  maxdinvol = 0
  maxnod = 0
  maxsam = 0
  maxnst = 0
  maxquan = 0
  maxmvlook = 0
  maxref = 0
  maxcat = 0
  maxctx = 0
  maxcty = 0
  maxctz = 0
  maxsbx = 0
  maxsby = 0
  maxsbz = 0

  ! Parse file
  do
    read(lin_tmp, '(a)', end=100) line
    line = adjustl(line)

    ! Skip comments and empty lines
    if (len_trim(line) == 0) cycle
    if (line(1:1) == '#') cycle

    ! Check for section headers
    if (line(1:1) == '[') then
      in_dimensions = (index(line, '[DIMENSIONS]') > 0)
      in_grid = (index(line, '[GRID]') > 0)
      in_search = (index(line, '[SEARCH]') > 0)
      cycle
    end if

    ! Parse key=value
    call parse_keyword_line(line, key, value, ierr)
    if (ierr /= 0) cycle

    ! Grid dimensions
    if (in_grid) then
      if (key == 'nx') read(value, *) nx
      if (key == 'ny') read(value, *) ny
      if (key == 'nz') read(value, *) nz
      if (key == 'xmin') read(value, *) xmn
      if (key == 'ymin') read(value, *) ymn
      if (key == 'zmin') read(value, *) zmn
      if (key == 'xsize') read(value, *) xsiz
      if (key == 'ysize') read(value, *) ysiz
      if (key == 'zsize') read(value, *) zsiz
    end if

    ! Search parameters
    if (in_search) then
      if (key == 'ndmax') read(value, *) ndmax_tmp
      if (key == 'nodmax') read(value, *) nodmax_tmp
    end if

    ! Explicit dimensions (if provided)
    if (in_dimensions) then
      if (key == 'max_data') read(value, *) maxdat
      if (key == 'max_volumes') read(value, *) maxvols
      if (key == 'max_data_in_volume') read(value, *) maxdinvol
      if (key == 'max_nodes_search') read(value, *) maxnod
      if (key == 'max_samples_kriging') read(value, *) maxsam
      if (key == 'max_structures') read(value, *) maxnst
      if (key == 'max_quantiles') read(value, *) maxquan
      if (key == 'max_mvlookup') read(value, *) maxmvlook
      if (key == 'max_reference') read(value, *) maxref
      if (key == 'max_categories') read(value, *) maxcat
      if (key == 'max_ctx') read(value, *) maxctx
      if (key == 'max_cty') read(value, *) maxcty
      if (key == 'max_ctz') read(value, *) maxctz
      if (key == 'max_sbx') read(value, *) maxsbx
      if (key == 'max_sby') read(value, *) maxsby
      if (key == 'max_sbz') read(value, *) maxsbz
    end if

  end do

100 close(lin_tmp)

  nxy = nx * ny
  nxyz = nx * ny * nz

  ! Auto-calculate dimensions if not explicitly provided
  ! Use defaults with safety margins
  if (maxdat == 0) maxdat = 50000
  if (maxvols == 0) maxvols = 805
  if (maxdinvol == 0) maxdinvol = 199
  if (maxnod == 0) maxnod = min(nodmax_tmp * 2, 2000)
  if (maxsam == 0) maxsam = min(ndmax_tmp + 50, 200)
  if (maxnst == 0) maxnst = 4
  if (maxquan == 0) maxquan = 501
  if (maxmvlook == 0) maxmvlook = 201
  if (maxref == 0) maxref = 10000
  if (maxcat == 0) maxcat = 24
  if (maxctx == 0) maxctx = nx
  if (maxcty == 0) maxcty = ny
  if (maxctz == 0) maxctz = nz
  if (maxsbx == 0) maxsbx = 21
  if (maxsby == 0) maxsby = 21
  if (maxsbz == 0) maxsbz = 11

end subroutine read_dimensions_keyword

!-----------------------------------------------------------------------
! Helper: set parameter filename for populate function
!-----------------------------------------------------------------------
subroutine set_parfile_for_populate(filename)
  use visim_readpar_populate
  character(len=*), intent(in) :: filename
  call set_parfile_name(filename)
end subroutine set_parfile_for_populate

!-----------------------------------------------------------------------
! readparm_populate - Second pass: populate allocated arrays
!-----------------------------------------------------------------------
subroutine readparm_populate()
  use visim_readpar_populate

  write(*,*)
  write(*,*) 'Reading parameters and data...'

  ! Call the comprehensive population routine
  call populate_all_parameters()

  write(*,*) 'Parameter reading complete.'

end subroutine readparm_populate

!-----------------------------------------------------------------------
! Utility: detect_format - Determine if file is legacy or keyword format
!-----------------------------------------------------------------------
subroutine detect_format(filename, ftype)
  character(len=*), intent(in) :: filename
  integer, intent(out) :: ftype
  character(len=MAX_LINE_LEN) :: line
  integer :: lin_tmp

  lin_tmp = 98
  open(lin_tmp, file=filename, status='OLD')

  ! Read first few non-empty lines
  do
    read(lin_tmp, '(a)', end=10) line
    line = adjustl(line)
    if (len_trim(line) == 0) cycle

    ! Check for keyword format indicators
    if (line(1:1) == '#') then
      ftype = 2  ! Comment suggests keyword format
      exit
    end if
    if (line(1:1) == '[') then
      ftype = 2  ! Section header = keyword format
      exit
    end if
    if (index(line, '=') > 0 .and. index(line, 'STAR') == 0) then
      ftype = 2  ! key=value pair
      exit
    end if
    if (index(line, 'START') > 0) then
      ftype = 1  ! Legacy format marker
      exit
    end if

    ! If we've read 10 lines without detecting, assume legacy
    exit
  end do

10 close(lin_tmp)
  if (ftype == 0) ftype = 1  ! Default to legacy

end subroutine detect_format

!-----------------------------------------------------------------------
! Utility: parse_keyword_line - Parse "key = value" line
!-----------------------------------------------------------------------
subroutine parse_keyword_line(line, key, value, ierr)
  character(len=*), intent(in) :: line
  character(len=*), intent(out) :: key, value
  integer, intent(out) :: ierr
  integer :: eq_pos

  ierr = 0
  eq_pos = index(line, '=')

  if (eq_pos == 0) then
    ierr = 1
    return
  end if

  key = adjustl(trim(line(1:eq_pos-1)))
  value = adjustl(trim(line(eq_pos+1:)))

  ! Convert key to lowercase for case-insensitive matching
  call to_lowercase(key)

end subroutine parse_keyword_line

!-----------------------------------------------------------------------
! Utility: to_lowercase - Convert string to lowercase
!-----------------------------------------------------------------------
subroutine to_lowercase(str)
  character(len=*), intent(inout) :: str
  integer :: i, ic

  do i = 1, len_trim(str)
    ic = ichar(str(i:i))
    if (ic >= 65 .and. ic <= 90) then  ! A-Z
      str(i:i) = char(ic + 32)  ! Convert to lowercase
    end if
  end do

end subroutine to_lowercase

!-----------------------------------------------------------------------
! Utility: get_parameter_filename - Get parameter file from command line
!-----------------------------------------------------------------------
subroutine get_parameter_filename(filename)
  character(len=*), intent(out) :: filename
  integer :: argc

  argc = iargc()

  if (argc >= 1) then
    call getarg(1, filename)
  else
    write(*,*) 'Which parameter file do you want to use?'
    read(*, '(a)') filename
  end if

  if (len_trim(filename) == 0) then
    filename = 'visim.par'
  end if

end subroutine get_parameter_filename

!-----------------------------------------------------------------------
! makepar_v2 - Create blank parameter file (keyword format)
!-----------------------------------------------------------------------
subroutine makepar_v2()
  integer :: lout_tmp

  lout_tmp = 97
  open(lout_tmp, file='visim.par', status='REPLACE')

  write(lout_tmp, '(a)') '# VISIM Parameter File (v2.0 - Keyword Format)'
  write(lout_tmp, '(a)') '# Generated by VISIM F90'
  write(lout_tmp, '(a)') ''
  write(lout_tmp, '(a)') '[GENERAL]'
  write(lout_tmp, '(a)') 'conditional_simulation = 1'
  write(lout_tmp, '(a)') 'debug_level = 0'
  write(lout_tmp, '(a)') ''
  write(lout_tmp, '(a)') '[FILES]'
  write(lout_tmp, '(a)') 'data_file = visim_cond.eas'
  write(lout_tmp, '(a)') 'volgeom_file = visim_volgeom.deas'
  write(lout_tmp, '(a)') 'volsum_file = visim_volsum.eas'
  write(lout_tmp, '(a)') 'output_file = visim.out'
  write(lout_tmp, '(a)') ''
  write(lout_tmp, '(a)') '[GRID]'
  write(lout_tmp, '(a)') 'nx = 40'
  write(lout_tmp, '(a)') 'ny = 40'
  write(lout_tmp, '(a)') 'nz = 1'
  write(lout_tmp, '(a)') 'xmin = 0.5'
  write(lout_tmp, '(a)') 'ymin = 0.5'
  write(lout_tmp, '(a)') 'zmin = 0.5'
  write(lout_tmp, '(a)') 'xsize = 1.0'
  write(lout_tmp, '(a)') 'ysize = 1.0'
  write(lout_tmp, '(a)') 'zsize = 1.0'
  write(lout_tmp, '(a)') ''
  write(lout_tmp, '(a)') '[SEARCH]'
  write(lout_tmp, '(a)') 'ndmin = 0'
  write(lout_tmp, '(a)') 'ndmax = 8'
  write(lout_tmp, '(a)') 'nodmax = 12'

  close(lout_tmp)

  write(*,*) 'Blank parameter file created: visim.par'

end subroutine makepar_v2

end module visim_readpar_v2
