class BrewsciMumps < Formula
  desc "Parallel Sparse Direct Solver"
  homepage "http://mumps-solver.org"
  url "http://mumps.enseeiht.fr/MUMPS_5.1.2.tar.gz"
  sha256 "eb345cda145da9aea01b851d17e54e7eef08e16bfa148100ac1f7f046cd42ae9"

  bottle do
    root_url "https://linuxbrew.bintray.com/bottles-num"
    cellar :any
    sha256 "6ae5924f6bd48c4efe8fd8f0bb232bbd95071815c83231ca4839c76720da707e" => :sierra
    sha256 "a587810429fe9f93d5ffa140de346fc2f6d45124ec759bdc5a911afdf125c23f" => :x86_64_linux
  end

  keg_only "formulae in brewsci/num are keg only"

  option "without-mpi", "build without MPI"

  depends_on "brewsci/num/brewsci-scalapack" if build.with? "mpi"
  depends_on "gcc"
  depends_on "open-mpi" if build.with? "mpi"
  depends_on "openblas"

  depends_on "brewsci/num/brewsci-metis" => :recommended if build.without? "mpi"
  depends_on "brewsci/num/brewsci-parmetis" => :recommended if build.with? "mpi"
  depends_on "brewsci/num/brewsci-scotch" => :optional
  depends_on "brewsci/num/brewsci-scotch@5" => :optional

  fails_with :clang # because we use OpenMP

  resource "mumps_simple" do
    url "https://github.com/dpo/mumps_simple/archive/v0.4.tar.gz"
    sha256 "87d1fc87eb04cfa1cba0ca0a18f051b348a93b0b2c2e97279b23994664ee437e"
  end

  def install
    make_args = ["RANLIB=echo"]
    if OS.mac?
      # Building dylibs with mpif90 causes segfaults on 10.8 and 10.10. Use gfortran.
      shlibs_args = ["LIBEXT=.dylib",
                     "AR=gfortran -dynamiclib -Wl,-install_name -Wl,#{lib}/$(notdir $@) -undefined dynamic_lookup -o "]
    else
      shlibs_args = ["LIBEXT=.so",
                     "AR=$(FL) -shared -Wl,-soname -Wl,$(notdir $@) -o "]
    end
    make_args += ["OPTF=-O", "CDEFS=-DAdd_"]
    orderingsf = "-Dpord"

    makefile = build.with?("mpi") ? "Makefile.G95.PAR" : "Makefile.G95.SEQ"
    cp "Make.inc/" + makefile, "Makefile.inc"

    if build.with? "brewsci-scotch@5"
      make_args += ["SCOTCHDIR=#{Formula["brewsci-scotch@5"].opt_prefix}",
                    "ISCOTCH=-I#{Formula["brewsci-scotch@5"].opt_include}"]

      if build.with? "mpi"
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR)/lib -lptesmumps -lptscotch -lptscotcherr"
        scotch_libs += " -lptscotchparmetis" if build.with? "parmetis"
        make_args << scotch_libs
        orderingsf << " -Dptscotch"
      else
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR) -lesmumps -lscotch -lscotcherr"
        scotch_libs += " -lscotchmetis" if build.with? "brewsci-metis"
        make_args << scotch_libs
        orderingsf << " -Dscotch"
      end
    elsif build.with? "scotch"
      make_args += ["SCOTCHDIR=#{Formula["brewsci-scotch"].opt_prefix}",
                    "ISCOTCH=-I#{Formula["brewsci-scotch"].opt_include}"]

      if build.with? "mpi"
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR)/lib -lptscotch -lptscotcherr -lptscotcherrexit -lscotch"
        scotch_libs += "-lptscotchparmetis" if build.with? "brewsci-parmetis"
        make_args << scotch_libs
        orderingsf << " -Dptscotch"
      else
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR) -lscotch -lscotcherr -lscotcherrexit"
        scotch_libs += "-lscotchmetis" if build.with? "brewsci-metis"
        make_args << scotch_libs
        orderingsf << " -Dscotch"
      end
    end

    if build.with? "brewsci-parmetis"
      make_args += ["LMETISDIR=#{Formula["brewsci-parmetis"].opt_lib}",
                    "IMETIS=#{Formula["brewsci-parmetis"].opt_include}",
                    "LMETIS=-L#{Formula["brewsci-parmetis"].opt_lib} -lparmetis -L#{Formula["brewsci-metis"].opt_lib} -lmetis"]
      orderingsf << " -Dparmetis"
    elsif build.with? "brewsci-metis"
      make_args += ["LMETISDIR=#{Formula["brewsci-metis"].opt_lib}",
                    "IMETIS=#{Formula["brewsci-metis"].opt_include}",
                    "LMETIS=-L#{Formula["brewsci-metis"].opt_lib} -lmetis"]
      orderingsf << " -Dmetis"
    end

    make_args << "ORDERINGSF=#{orderingsf}"

    if build.with? "mpi"
      make_args += ["CC=mpicc -fPIC",
                    "FC=mpif90 -fPIC",
                    "FL=mpif90 -fPIC",
                    "SCALAP=-L#{Formula["brewsci-scalapack"].opt_lib} -lscalapack",
                    "INCPAR=", # Let MPI compilers fill in the blanks.
                    "LIBPAR=$(SCALAP)"]
    else
      make_args += ["CC=#{ENV["CC"]} -fPIC",
                    "FC=gfortran -fPIC -fopenmp",
                    "FL=gfortran -fPIC -fopenmp"]
    end

    make_args << "LIBBLAS=-L#{Formula["openblas"].opt_lib} -lopenblas"

    ENV.deparallelize # Build fails in parallel on Mavericks.

    system "make", "alllib", *(shlibs_args + make_args)

    lib.install Dir["lib/*"]
    lib.install ("libseq/libmpiseq" + (OS.mac? ? ".dylib" : ".so")) if build.without? "mpi"

    # Build static libraries (e.g., for Dolfin)
    system "make", "alllib", *make_args
    (libexec/"lib").install Dir["lib/*.a"]
    (libexec/"lib").install "libseq/libmpiseq.a" if build.without? "mpi"

    inreplace "examples/Makefile" do |s|
      s.change_make_var! "libdir", lib
    end

    libexec.install "include"
    include.install_symlink Dir[libexec/"include/*"]
    # The following .h files may conflict with others related to MPI
    # in /usr/local/include. Do not symlink them.
    (libexec/"include").install Dir["libseq/*.h"] if build.without? "mpi"

    doc.install Dir["doc/*.pdf"]
    pkgshare.install "examples"

    prefix.install "Makefile.inc"  # For the record.
    File.open(prefix/"make_args.txt", "w") do |f|
      f.puts(make_args.join(" "))  # Record options passed to make.
    end

    if build.with? "mpi"
      resource("mumps_simple").stage do
        simple_args = ["CC=mpicc", "prefix=#{prefix}", "mumps_prefix=#{prefix}",
                       "scalapack_libdir=#{Formula["brewsci-scalapack"].opt_lib}"]
        if build.with? "brewsci-scotch@5"
          simple_args += ["scotch_libdir=#{Formula["brewsci-scotch@5"].opt_lib}",
                          "scotch_libs=-L$(scotch_libdir) -lptesmumps -lptscotch -lptscotcherr"]
        elsif build.with? "brewsci-scotch"
          simple_args += ["scotch_libdir=#{Formula["brewsci-scotch"].opt_lib}",
                          "scotch_libs=-L$(scotch_libdir) -lptscotch -lptscotcherr -lscotch"]
        end
        simple_args += ["blas_libdir=#{Formula["openblas"].opt_lib}",
                        "blas_libs=-L$(blas_libdir) -lopenblas"]
        system "make", "SHELL=/bin/bash", *simple_args
        lib.install ("libmumps_simple." + (OS.mac? ? "dylib" : "so"))
        include.install "mumps_simple.h"
      end
    end
  end

  def caveats
    s = <<~EOS
      MUMPS was built with shared libraries. If required,
      static libraries are available in
        #{opt_libexec}/lib
    EOS
    if build.without? "mpi"
      s += <<~EOS
        You built a sequential MUMPS library.
        Please add #{libexec}/include to the include path
        when building software that depends on MUMPS.
      EOS
    end
    s
  end

  test do
    ENV.prepend_path "LD_LIBRARY_PATH", lib unless OS.mac?
    cp_r pkgshare/"examples", testpath
    opts = ["-fopenmp"]
    if Tab.for_name("brewsci-mumps").with?("mpi")
      ENV.prepend_path "LD_LIBRARY_PATH", Formula["brewsci-scalapack"].opt_lib unless OS.mac?
      f90 = "mpif90"
      cc = "mpicc"
      mpirun = "mpirun -np 1"
      includes = "-I#{opt_include}"
      opts << "-L#{Formula["brewsci-scalapack"].opt_lib}" << "-lscalapack" << "-L#{opt_lib}"
    else
      ENV.prepend_path "LD_LIBRARY_PATH", "#{opt_libexec}/lib" unless OS.mac?
      f90 = "gfortran"
      cc = ENV["CC"]
      mpirun = ""
      includes = "-I#{opt_libexec}/include"
      opts << "-L#{opt_libexec}/lib" << "-lmpiseq"
    end
    if Tab.for_name("brewsci-mumps").with?("brewsci-parmetis")
      ENV.prepend_path "LD_LIBRARY_PATH", Formula["brewsci-parmetis"].opt_lib unless OS.mac?
      opts << "-L#{Formula["brewsci-parmetis"].opt_lib}" << "-lparmetis"
    end
    if Tab.for_name("brewsci-mumps").with?("brewsci-metis")
      ENV.prepend_path "LD_LIBRARY_PATH", Formula["brewsci-metis"].opt_lib unless OS.mac?
      opts << "-L#{Formula["brewsci-metis"].opt_lib}" << "-lmetis"
    end
    opts << "-lmumps_common" << "-lpord"
    opts << "-L#{Formula["openblas"].opt_lib}" << "-lopenblas"

    cd testpath/"examples" do
      system f90, "-o", "ssimpletest", "ssimpletest.F", "-lsmumps", includes, *opts
      system "#{mpirun} ./ssimpletest < input_simpletest_real"
      system f90, "-o", "dsimpletest", "dsimpletest.F", "-ldmumps", includes, *opts
      system "#{mpirun} ./dsimpletest < input_simpletest_real"
      system f90, "-o", "csimpletest", "csimpletest.F", "-lcmumps", includes, *opts
      system "#{mpirun} ./csimpletest < input_simpletest_cmplx"
      system f90, "-o", "zsimpletest", "zsimpletest.F", "-lzmumps", includes, *opts
      system "#{mpirun} ./zsimpletest < input_simpletest_cmplx"
      system cc, "-c", "c_example.c", includes
      system f90, "-o", "c_example", "c_example.o", "-ldmumps", *opts
      system *(mpirun.split + ["./c_example"] + opts)
    end
  end
end